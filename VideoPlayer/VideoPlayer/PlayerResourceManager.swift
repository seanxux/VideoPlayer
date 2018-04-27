//
//  PlayerResourceManager.swift
//  DriverDemo
//
//  Created by XUXIAOTENG on 14/12/2017.
//  Copyright © 2017 Bravesoft. All rights reserved.
//

import UIKit
import AVKit
import MobileCoreServices

class PlayerResourceManager: NSObject {
    
    var videoURL: URL
    var videoScheme: String
    var media: PlayerMedia?
    var pendingDownloads: [PlayerDownloader] = []
    lazy var playerCacher = PlayerCacher(url: videoURL)
    
    let downloadQueue = OperationQueue()
    
    deinit {
        self.media?.save()
    }
    
    init(videoURL: URL, videoScheme: String) {
        self.videoURL = videoURL
        self.videoScheme = videoScheme
        
        super.init()
    }
    
    func startRequest(loadingRequest: AVAssetResourceLoadingRequest) {
        if self.media == nil {
            let filePath = PlayerCacher.cacheFilePath(for: videoURL)
            
            if let media = PlayerMedia.media(filePath: filePath) {
                self.media = media
                self.fillContentInformation(loadingRequest: loadingRequest)
            }
        }
        
        guard let dataRequest = loadingRequest.dataRequest else {
            return
        }
        var offset = dataRequest.requestedOffset
        var length = dataRequest.requestedLength
        if dataRequest.currentOffset != 0 {
            offset = dataRequest.currentOffset
        }
        
        if #available(iOS 9.0, *) {
            if dataRequest.requestsAllDataToEndOfResource {
                if let contentLength = self.media?.contentLength {
                    length = Int(contentLength) - Int(offset) - 1
                } else {
                    length = 0 - Int(offset)
                }
            }
        }
        let range = NSMakeRange(Int(offset), length)
        var dataExist = false
        if let media = self.media {
            if media.cachedDataExist(segment: range) {
                if let data = cachedData(loadingRequest: loadingRequest, range: range) {
                    loadingRequest.dataRequest?.respond(with: data)
                    loadingRequest.finishLoading()
                    dataExist = true
                }
            }
        }
        if !dataExist {
            startDownload(loadingRequest: loadingRequest)
        }
    }
    
    func cachedData(loadingRequest: AVAssetResourceLoadingRequest, range: NSRange) -> Data? {
        return playerCacher.cachedData(range: range)
    }
    
    func startDownload(loadingRequest: AVAssetResourceLoadingRequest) {
        let downloader = PlayerDownloader(media: media)
        downloader.fillMedia = { [unowned self] (media) in
            self.media = media
            self.media?.filePath = PlayerCacher.cacheFilePath(for: self.videoURL)
            self.media?.save()
            self.fillContentInformation(loadingRequest: loadingRequest)
            if let m = media {
                self.playerCacher.truncateFile(media: m)
            }
            print(self.media ?? "media is empty")
        }
        downloader.downloaderDidReceiveData = { [unowned self] (downloader, data) in
            let range = NSMakeRange(downloader.startOffset, data.count)
            self.playerCacher.cache(data: data, range: range)
            self.playerCacher.save()
            self.media?.addCache(segment: range)
        }
        downloader.downloaderDidReceiveResponse = { (downloader, response) in
            
        }
        downloader.downloaderDidComplete = { [unowned self] (downloader, error) in
            self.media?.save()
            if let index = self.pendingDownloads.index(of: downloader) {
                self.pendingDownloads.remove(at: index)
            }
        }
        
        downloader.startRequest(loadingRequest, queue: downloadQueue)
        self.pendingDownloads.append(downloader)
    }
    
    func cancelRequest(loadingRequest: AVAssetResourceLoadingRequest) {
        for (i, downloader) in pendingDownloads.enumerated() {
            if downloader.loadingRequest == loadingRequest {
                downloader.cancel()
                pendingDownloads.remove(at: i)
                break
            }
        }
    }
    
    func fillContentInformation(loadingRequest: AVAssetResourceLoadingRequest) {
        guard let media = media else {
            return
        }
        loadingRequest.contentInformationRequest?.contentType = media.contentType
        loadingRequest.contentInformationRequest?.contentLength = media.contentLength
        loadingRequest.contentInformationRequest?.isByteRangeAccessSupported = media.isByteRangeAccessSupported
    }

}

extension PlayerResourceManager: AVAssetResourceLoaderDelegate {
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let url = loadingRequest.request.url else {
            return false
        }
        if url.scheme == videoScheme {
            startRequest(loadingRequest: loadingRequest)
            return true
        }
        return false
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        print("resourceLoader canceled")
        cancelRequest(loadingRequest: loadingRequest)
    }
    
}
