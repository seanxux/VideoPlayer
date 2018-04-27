//
//  PlayerDownloader.swift
//  DriverDemo
//
//  Created by XUXIAOTENG on 13/12/2017.
//  Copyright © 2017 Bravesoft. All rights reserved.
//

import UIKit
import AVKit
import Alamofire
import MobileCoreServices

class PlayerDownloader: NSObject {

    let httpScheme = "http"
    var videoURL: URL?
    
    var loadingRequest: AVAssetResourceLoadingRequest!
    
    fileprivate var session: URLSession?
    fileprivate var task: URLSessionDataTask?
    
    fileprivate let dataQueue = DispatchQueue(label: "cn.gxm.dataQueue")
    
    var bufferSize = 10 * 1024
    var bufferData = Data()
    var startOffset: Int = 0
    
    
    var mediaInfo: PlayerMedia?
    
    var fillMedia: ((_ media: PlayerMedia?) -> Void)?
    var downloaderDidReceiveData: ((_ downloader: PlayerDownloader, _ data: Data) -> Void)?
    var downloaderDidComplete: ((_ downloader: PlayerDownloader, _ error: Error?) -> Void)?
    var downloaderDidReceiveResponse: ((_ downloader: PlayerDownloader, _ response: URLResponse) -> Void)?
    
    init(media: PlayerMedia?) {
        mediaInfo = media
        super.init()
    }
    
    func startRequest(_ loadingRequest: AVAssetResourceLoadingRequest, queue: OperationQueue) {
        guard let url = loadingRequest.request.url else {
            return
        }
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.scheme = httpScheme
        videoURL = urlComponents?.url
        
        self.loadingRequest = loadingRequest
        let sessionConfiguration = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: queue)
        self.session = session
        
        guard let dataRequest = loadingRequest.dataRequest else {
            return
        }
        
        var offset = dataRequest.requestedOffset
        let length = dataRequest.requestedLength
        if dataRequest.currentOffset != 0 {
            offset = dataRequest.currentOffset
        }
        var isEnd = false
        if #available(iOS 9.0, *) {
            if dataRequest.requestsAllDataToEndOfResource {
                isEnd = true
            }
        }
        startDownload(offset: Int(offset), length: length, isEnd: isEnd)
    }
    
    func startDownload(offset: Int, length: Int, isEnd: Bool) {
        startOffset = offset
        
        guard let url = videoURL else {
            return
        }
        var request = URLRequest(url: url)
        
        var endOffset = offset + length - 1
        if isEnd {
            if let contentLength = mediaInfo?.contentLength {
                endOffset = Int(contentLength) - 1
            } else {
                endOffset = 0 - offset
            }
        }
        
        let range = String(format: "bytes=%lld-%lld", offset, endOffset)
        request.setValue(range, forHTTPHeaderField: "Range")
        print("range: \(range)")
        
        task = session?.dataTask(with: request)
        task?.resume()
    }
    
    func cancel() {
        task?.cancel()
    }
    
}

extension PlayerDownloader: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        dataQueue.sync {
            bufferData.append(data)
            if bufferData.count > bufferSize {
                let chunkRange: Range = 0..<bufferData.count
                let chunkData = bufferData.subdata(in: chunkRange)
                bufferData.removeAll()
                loadingRequest.dataRequest?.respond(with: chunkData)
                if let callback = downloaderDidReceiveData {
                    callback(self, chunkData)
                }
                startOffset += chunkData.count
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        dataQueue.sync {
            if error == nil {
                if bufferData.count > 0 {
                    let chunkRange: Range = 0..<bufferData.count
                    let chunkData = bufferData.subdata(in: chunkRange)
                    bufferData.removeAll()
                    loadingRequest.dataRequest?.respond(with: chunkData)
                    if let callback = downloaderDidReceiveData {
                        callback(self, chunkData)
                    }
                }
                loadingRequest.finishLoading()
            } else {
                print("complete with error: \(String(describing: error))")
            }
            if let callback = downloaderDidComplete {
                callback(self, error)
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if mediaInfo == nil {
            let media = PlayerMedia()
            guard let httpURLResponse = response as? HTTPURLResponse else {
                return
            }
            
            // set header
            let acceptRange = httpURLResponse.allHeaderFields["Accept-Ranges"] as? String
            if let bytes = acceptRange?.isEqual("bytes") {
                media.isByteRangeAccessSupported = bytes
            }
            // fix swift allHeaderFields NO! case insensitive
            let contentRange = httpURLResponse.allHeaderFields["content-range"] as? String
            let contentRang = httpURLResponse.allHeaderFields["Content-Range"] as? String
            if let last = contentRange?.components(separatedBy: "/").last {
                media.contentLength = Int64(last)!
            }
            if let last = contentRang?.components(separatedBy: "/").last {
                media.contentLength = Int64(last)!
            }
            
            if let mimeType = httpURLResponse.mimeType {
                let cType =  UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
                if let takeUnretainedValue = cType?.takeUnretainedValue() {
                    media.contentType = takeUnretainedValue as String
                }
            }
            mediaInfo = media
            
            if let callback = fillMedia {
                callback(media)
            }
        }
        
        completionHandler(.allow)
        
        if let callback = downloaderDidReceiveResponse {
            callback(self, response)
        }
        print("finish: \(response)")
    }
    
}
