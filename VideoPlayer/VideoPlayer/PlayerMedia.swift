//
//  PlayerMedia.swift
//  DriverDemo
//
//  Created by XUXIAOTENG on 13/12/2017.
//  Copyright © 2017 Bravesoft. All rights reserved.
//

import UIKit

open class PlayerMedia: NSObject, NSCoding, NSCopying {

    open var filePath: String?
    open var contentType: String?
    open var isByteRangeAccessSupported = false
    open var contentLength: Int64 = 0
    open var downloadedLength: UInt64 = 0
    open var segmentRanges: [NSValue] = []
    
    fileprivate let segmentQueue = DispatchQueue(label: "com.gxm.segmentQueue")
    
    override open var description: String {
        return "contentType: \(String(describing: contentType))\n isByteRangeAccessSupported: \(isByteRangeAccessSupported)\n contentLength: \(contentLength)\n downloadedLength: \(downloadedLength)\n"
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(contentType, forKey: "contentType")
        aCoder.encode(isByteRangeAccessSupported, forKey: "isByteRangeAccessSupported")
        aCoder.encode(contentLength, forKey: "contentLength")
        aCoder.encode(downloadedLength, forKey: "downloadedLength")
        aCoder.encode(segmentRanges, forKey: "segmentRanges")
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let media = PlayerMedia()
        media.filePath = filePath
        media.contentType = contentType
        media.isByteRangeAccessSupported = isByteRangeAccessSupported
        media.contentLength = contentLength
        media.downloadedLength = downloadedLength
        media.segmentRanges = segmentRanges
        return media
    }
    
    public override init() {
        
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init()
        contentType = aDecoder.decodeObject(forKey: "contentType") as? String
        isByteRangeAccessSupported = aDecoder.decodeBool(forKey: "isByteRangeAccessSupported")
        contentLength = aDecoder.decodeInt64(forKey: "contentLength")
        if let downloadedLength = aDecoder.decodeObject(forKey: "downloadedLength") as? UInt64 {
            self.downloadedLength = downloadedLength
        } else {
            downloadedLength = 0
        }
        if let ranges = aDecoder.decodeObject(forKey:"segmentRanges") as? Array<NSValue> {
            self.segmentRanges = ranges
        } else {
            self.segmentRanges = []
        }
    }
    
    public static func configFilePath(_ filePath: String) -> String {
        let nsString = filePath as NSString
        return nsString.appendingPathExtension("conf")!
    }
    
    public static func media(filePath: String) -> PlayerMedia? {
        let path = self.configFilePath(filePath)
        guard let media = (NSKeyedUnarchiver.unarchiveObject(withFile: path) as? PlayerMedia) else {
            return nil
        }
        media.filePath = filePath
        return media
    }
    
    public func save() {
        let path = PlayerMedia.configFilePath(filePath!)
        let result = NSKeyedArchiver.archiveRootObject(self, toFile: path)
        print("archive result: \(result)")
    }
    
    func addCache(segment: NSRange) {
        if segment.location == NSNotFound || segment.length == 0 {
            return
        }
        segmentQueue.sync {
            let segmentValue = NSValue(range: segment)
            var cacheSegments = self.segmentRanges
            let count = self.segmentRanges.count
            
            if cacheSegments.count == 0 {
                cacheSegments.append(segmentValue)
            } else {
                let indexSet = NSMutableIndexSet()
                for (index, value) in cacheSegments.enumerated() {
                    let range = value.rangeValue
                    
                    if (segment.location + segment.length) <= range.location {
                        if (indexSet.count == 0) {
                            indexSet.add(index)
                        }
                        break
                    } else if (segment.location <= (range.location + range.length) && (segment.location + segment.length) > range.location) {
                        indexSet.add(index)
                    } else if (segment.location >= range.location + range.length) {
                        if index == count - 1 {
                            indexSet.add(index)
                        }
                    }
                    
                }
                
                if indexSet.count > 1 {
                    let firstRange = self.segmentRanges[indexSet.firstIndex].rangeValue
                    let lastRange = self.segmentRanges[indexSet.lastIndex].rangeValue
                    let location = min(firstRange.location, segment.location)
                    let endOffset = max(lastRange.location + lastRange.length, segment.location + segment.length)
                    
                    let combineRange = NSMakeRange(location, endOffset - location)
                    let _ = indexSet.sorted(by: >).map {cacheSegments.remove(at: $0)}
                    cacheSegments.insert(NSValue(range:combineRange), at: indexSet.firstIndex)
                } else if indexSet.count == 1 {
                    let firstRange = self.segmentRanges[indexSet.firstIndex].rangeValue
                    let expandFirstRange = NSMakeRange(firstRange.location, firstRange.length + 1)
                    let expandSegmentRange = NSMakeRange(segment.location, segment.length + 1)
                    let intersectionRange = NSIntersectionRange(expandFirstRange, expandSegmentRange)
                    
                    if intersectionRange.length > 0 {
                        let location = min(firstRange.location, segment.location)
                        let endOffset = max(firstRange.location + firstRange.length, segment.location + segment.length)
                        let combineRange = NSMakeRange(location, endOffset - location)
                        cacheSegments.remove(at: indexSet.firstIndex)
                        cacheSegments.insert(NSValue(range:combineRange), at: indexSet.firstIndex)
                    } else {
                        if firstRange.location > segment.location {
                            cacheSegments.insert(segmentValue, at: indexSet.lastIndex)
                        } else {
                            cacheSegments.insert(segmentValue, at: indexSet.lastIndex + 1)
                        }
                    }
                }
            }
            
//            var combineSegments: [NSValue] = []
//            for value in cacheSegments {
//                let range = value.rangeValue
//                if combineSegments.count == 0 {
//                    combineSegments.append(value)
//                } else {
//                    if let lastRange = combineSegments.last?.rangeValue {
//                        if lastRange.location + lastRange.length == range.location {
//                            let combineRange = NSMakeRange(lastRange.location, lastRange.length + range.length)
//                            combineSegments.removeLast(1)
//                            combineSegments.append(NSValue(range: combineRange))
//                        } else {
//                            combineSegments.append(value)
//                        }
//                    } else {
//                        combineSegments.append(value)
//                    }
//                }
//            }
            self.segmentRanges = cacheSegments
        }
    }
    
    func cachedDataExist(segment: NSRange) -> Bool {
        if segment.location == NSNotFound {
            return false
        }
        
        for range in segmentRanges {
            let intersectionRange = NSIntersectionRange(range.rangeValue, segment)
            if intersectionRange.length == segment.length {
                return true
            }
        }
        return false
        
//        let endOffset = segment.location + segment.length
//
//        for (_, value) in segmentRanges.enumerated() {
//            let segmentRange = value.rangeValue
//            let intersctionRange = NSIntersectionRange(range, segmentRange)
//            if intersctionRange.length > 0 {
//                let package = intersctionRange.length / kPackageLength
//                for i in 0...package {
//                    let offset = i * kPackageLength
//                    let offsetLocation = intersctionRange.location + offset
//                    let maxLocation = intersctionRange.location + intersctionRange.length
//                    let length = (offsetLocation + kPackageLength) > maxLocation ? (maxLocation - offsetLocation) : kPackageLength
//                    let ra = NSMakeRange(offsetLocation, length)
//                    let action = VGPlayerCacheAction(type: .local, range: ra)
//                    actions.append(action)
//                }
//            } else if segmentRange.location >= endOffset {
//                break
//            }
//        }
//
//        if actions.count == 0 {
//            let action = VGPlayerCacheAction(type: .remote, range: range)
//            actions.append(action)
//        } else {
//            var localRemoteActions = [VGPlayerCacheAction]()
//            for (index, value) in actions.enumerated() {
//                let actionRange = value.range
//                if index == 0 {
//                    if range.location < actionRange.location {
//                        let ra = NSMakeRange(range.location, actionRange.location - range.location)
//                        let action = VGPlayerCacheAction(type: .remote, range: ra)
//                        localRemoteActions.append(action)
//                    }
//                    localRemoteActions.append(value)
//                } else {
//                    if let lastAction = localRemoteActions.last {
//                        let lastOffset = lastAction.range.location + lastAction.range.length
//                        if actionRange.location > lastOffset {
//                            let ra = NSMakeRange(lastOffset, actionRange.location - lastOffset)
//                            let action = VGPlayerCacheAction(type: .remote, range: ra)
//                            localRemoteActions.append(action)
//                        }
//                    }
//                    localRemoteActions.append(value)
//                }
//
//                if index == actions.count - 1 {
//                    let localEndOffset = actionRange.location + actionRange.length
//                    if endOffset > localEndOffset {
//                        let ra = NSMakeRange(localEndOffset, endOffset)
//                        let action = VGPlayerCacheAction(type: .remote, range: ra)
//                        localRemoteActions.append(action)
//                    }
//                }
//            }
//
//            actions = localRemoteActions
//        }
//        return actions
    }
    
}
