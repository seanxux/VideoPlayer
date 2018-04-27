//
//  PlayerCacher.swift
//  DriverDemo
//
//  Created by XUXIAOTENG on 14/12/2017.
//  Copyright © 2017 Bravesoft. All rights reserved.
//

import UIKit

class PlayerCacher: NSObject {
    
    static let cacheRoot = "PlayerCache"
    fileprivate let fileQueue = DispatchQueue(label: "cn.gxm.fileQueue")
    
    fileprivate var filePath: String
    
    fileprivate var readFileHandle: FileHandle?
    fileprivate var writeFileHandle: FileHandle?
    
    var fileManager: FileManager

    deinit {
        save()
        readFileHandle?.closeFile()
        writeFileHandle?.closeFile()
    }
    
    init(url: URL) {
        filePath = PlayerCacher.cacheFilePath(for: url)
        fileManager = FileManager.default
        
        // create cache root directory
        let cacheDirectory = (filePath as NSString).deletingLastPathComponent
        var fileError: Error?
        if !fileManager.fileExists(atPath: cacheDirectory) {
            do {
                try fileManager.createDirectory(atPath: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fileError = error
            }
        }
        guard fileError == nil else {
            super.init()
            return
        }
        
        // create file
        if !fileManager.fileExists(atPath: filePath) {
            fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
        }
        // read file handle
        readFileHandle = FileHandle(forReadingAtPath: filePath)
        // write file handle
        writeFileHandle = FileHandle(forWritingAtPath: filePath)
        
        super.init()
    }
    
    static func cacheDirectory() -> String {
        return NSTemporaryDirectory().appending(PlayerCacher.cacheRoot)
    }
    
    static func cacheFilePath(for url: URL) -> String {
        let cacheFilePath = (cacheDirectory() as NSString).appendingPathComponent(url.lastPathComponent)
        return cacheFilePath
        
//        if let cacheFolder = url.lastPathComponent.components(separatedBy: ".").first {
//            let cacheFilePath = (cacheDirectory().appending("/\(cacheFolder)") as NSString).appendingPathComponent(url.lastPathComponent)
//            return cacheFilePath
//        }
//
//        return (NSTemporaryDirectory() as NSString).appendingPathComponent(url.lastPathComponent)
    }
    
    func truncateFile(media: PlayerMedia) {
        writeFileHandle?.truncateFile(atOffset: UInt64(media.contentLength))
        writeFileHandle?.synchronizeFile()
    }
    
    func cache(data: Data, range: NSRange) {
        fileQueue.sync {
            writeFileHandle?.seek(toFileOffset: UInt64(range.location))
            writeFileHandle?.write(data)
        }
    }
    
    func cachedData(range: NSRange) -> Data? {
        readFileHandle?.seek(toFileOffset: UInt64(range.location))
        return readFileHandle?.readData(ofLength: range.length)
    }
    
    func save() {
        fileQueue.sync {
            writeFileHandle?.synchronizeFile()
        }
    }
    
}
