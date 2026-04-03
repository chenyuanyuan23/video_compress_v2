import Flutter
import UIKit
import AVFoundation

public class VideoCompressV2Plugin: NSObject, FlutterPlugin {
    private let channelName = "video_compress"
    private var exporter: AVAssetExportSession? = nil
    private var stopCommand = false
    private let avController = AvController()
    private let channel: FlutterMethodChannel
    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "video_compress", binaryMessenger: registrar.messenger())
        let instance = VideoCompressV2Plugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? Dictionary<String, Any>
        switch call.method {
        case "getByteThumbnail":
            let path = args!["path"] as! String
            let quality = args!["quality"] as! NSNumber
            let position = args!["position"] as! NSNumber
            getByteThumbnail(path, quality, position, result)
        case "getFileThumbnail":
            let path = args!["path"] as! String
            let quality = args!["quality"] as! NSNumber
            let position = args!["position"] as! NSNumber
            getFileThumbnail(path, quality, position, result)
        case "getMediaInfo":
            let path = args!["path"] as! String
            getMediaInfo(path, result)
        case "compressVideo":
            let path = args!["path"] as! String
            let unique = args!["unique"] as! String
            let quality = args!["quality"] as! NSNumber
            let deleteOrigin = args!["deleteOrigin"] as! Bool
            let startTime = args!["startTime"] as? Double
            let duration = args!["duration"] as? Double
            let includeAudio = args!["includeAudio"] as? Bool
            let frameRate = args!["frameRate"] as? Int
            compressVideo(path,unique, quality, deleteOrigin, startTime, duration, includeAudio,
                          frameRate, result)
        case "getCompressDir":
            let url = "\(Utility.basePath())/"
            result(url)
        case "cancelCompression":
            cancelCompression(result)
        case "deleteAllCache":
            Utility.deleteFile(Utility.basePath(), clear: true)
            result(true)
        case "setLogLevel":
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    private func CMTimeMakeWithMilliseconds(_ value: Int64, timeScale: Int32) -> CMTime {
        return CMTimeMake(value: value, timescale: timeScale)
    }
    private func getBitMap(_ path: String,_ quality: NSNumber,_ position: NSNumber,_ result: FlutterResult)-> Data?  {
        let url = Utility.getPathUrl(path)
        let asset = avController.getVideoAsset(url)
        guard avController.getTrack(asset) != nil else { return nil }
        
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        
        let timeScale = asset.duration.timescale
        let time = CMTimeMakeWithSeconds(Double(truncating: position) / 1000.0, preferredTimescale:timeScale)
        guard let img = try? assetImgGenerate.copyCGImage(at:time, actualTime: nil) else {
            return nil
        }
        
        let thumbnail = UIImage(cgImage: img)
        let compressionQuality = CGFloat(0.01 * Double(truncating: quality))
        return thumbnail.jpegData(compressionQuality: compressionQuality)
    }
    
    private func getByteThumbnail(_ path: String,_ quality: NSNumber,_ position: NSNumber,_ result: FlutterResult) {
        if let bitmap = getBitMap(path,quality,position,result) {
            result(bitmap)
        }
    }
    
    private func getFileThumbnail(_ path: String,_ quality: NSNumber,_ position: NSNumber,_ result: FlutterResult) {
        let fileName = Utility.getFileName(path)
        let url = Utility.getPathUrl("\(Utility.basePath())/\(fileName).jpg")
        Utility.deleteFile(path)
        if let bitmap = getBitMap(path,quality,position,result) {
            guard (try? bitmap.write(to: url)) != nil else {
                return result(FlutterError(code: channelName,message: "getFileThumbnail error",details: "getFileThumbnail error"))
            }
            result(Utility.excludeFileProtocol(url.absoluteString))
        }
    }
    
    public func getMediaInfoJson(_ path: String)->[String : Any?] {
        let url = Utility.getPathUrl(path)
        let asset = avController.getVideoAsset(url)
        guard let track = avController.getTrack(asset) else { return [:] }

        // 复用同一个 asset，避免重复创建
        let orientation = avController.getVideoOrientation(from: track)
        let title = avController.getMetaDataByTag(asset, key: "title")
        let author = avController.getMetaDataByTag(asset, key: "author")

        let duration = asset.duration.seconds * 1000
        let filesize = track.totalSampleDataLength

        let size = track.naturalSize.applying(track.preferredTransform)

        let width = abs(size.width)
        let height = abs(size.height)

        let dictionary = [
            "path":Utility.excludeFileProtocol(path),
            "title":title,
            "author":author,
            "width":width,
            "height":height,
            "duration":duration,
            "filesize":filesize,
            "orientation":orientation
        ] as [String : Any?]
        return dictionary
    }
    
    private func getMediaInfo(_ path: String,_ result: FlutterResult) {
        let json = getMediaInfoJson(path)
        let string = Utility.keyValueToJson(json)
        result(string)
    }
    
    
    @objc private func updateProgress(timer:Timer) {
        guard let userInfo = timer.userInfo as? [String: Any],
              let asset = userInfo["exporter"] as? AVAssetExportSession,
              let unique = userInfo["unique"] as? String else {
            return
        }
        
        if !stopCommand {
            let arguments: [String: Any] = [
                "unique": unique,
                "progress": asset.progress * 100,
            ]
            channel.invokeMethod("updateProgress", arguments: arguments)
        }
    }
    
    private func getExportPreset(_ quality: NSNumber)->String {
        switch(quality) {
        case 1:
            return AVAssetExportPresetLowQuality
        case 2:
            return AVAssetExportPresetMediumQuality
        case 3:
            return AVAssetExportPresetHighestQuality
        case 4:
            return AVAssetExportPreset640x480
        case 5:
            return AVAssetExportPreset960x540
        case 6:
            return AVAssetExportPreset1280x720
        case 7:
            return AVAssetExportPreset1920x1080
        default:
            return AVAssetExportPresetMediumQuality
        }
    }
    
    private func getComposition(_ isIncludeAudio: Bool,_ timeRange: CMTimeRange, _ sourceVideoTrack: AVAssetTrack)->AVAsset {
        let composition = AVMutableComposition()
        if !isIncludeAudio {
            let compressionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
            compressionVideoTrack!.preferredTransform = sourceVideoTrack.preferredTransform
            try? compressionVideoTrack!.insertTimeRange(timeRange, of: sourceVideoTrack, at: CMTime.zero)
        } else {
            return sourceVideoTrack.asset!
        }
        
        return composition
    }
    
    private func compressVideo(_ path: String, _ unique: String, _ quality: NSNumber, _ deleteOrigin: Bool, _ startTime: Double?,
                               _ duration: Double?, _ includeAudio: Bool?, _ frameRate: Int?,
                               _ result: @escaping FlutterResult) {
        // 在后台线程执行视频处理，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { result("") }
                return
            }

            let sourceVideoUrl = Utility.getPathUrl(path)
            let sourceVideoType = "mp4"

            let sourceVideoAsset = self.avController.getVideoAsset(sourceVideoUrl)
            var sourceVideoTrack: AVAssetTrack?

            // 重试机制：最多重试5次，每次间隔0.5秒
            for _ in 0..<5 {
                sourceVideoTrack = self.avController.getTrack(sourceVideoAsset)
                if sourceVideoTrack != nil {
                    break
                }
                Thread.sleep(forTimeInterval: 0.5)
            }

            if sourceVideoTrack == nil {
                DispatchQueue.main.async { result("") }
                return
            }

            self.doCompressVideo(
                path: path,
                unique: unique,
                quality: quality,
                deleteOrigin: deleteOrigin,
                startTime: startTime,
                duration: duration,
                includeAudio: includeAudio,
                frameRate: frameRate,
                sourceVideoAsset: sourceVideoAsset,
                sourceVideoTrack: sourceVideoTrack!,
                result: result
            )
        }
    }

    private func doCompressVideo(path: String, unique: String, quality: NSNumber, deleteOrigin: Bool,
                                  startTime: Double?, duration: Double?, includeAudio: Bool?, frameRate: Int?,
                                  sourceVideoAsset: AVURLAsset, sourceVideoTrack: AVAssetTrack,
                                  result: @escaping FlutterResult) {
        let sourceVideoType = "mp4"

        let transform = sourceVideoTrack.preferredTransform

        var naturalSize: CGSize?
        naturalSize = sourceVideoTrack.naturalSize.applying(transform)
        naturalSize!.width = abs(naturalSize?.width ?? 0)
        naturalSize!.height = abs(naturalSize?.height ?? 0)
        
        // 分辨率
        var targetSize = naturalSize
        if let size = naturalSize {
            let minDimension = min(size.width, size.height)
            var targetDimension: CGFloat = 0
            
            switch Int(truncating: quality) {
            case 1:
                targetDimension = 480
            case 2:
                targetDimension = 540
            case 3:
                targetDimension = 720
            case 4:
                targetDimension = 1080
            default:
                break
            }
            
            if targetDimension > 0 {
                let aspectRatio = size.width / size.height
                var targetWidth: CGFloat = 0
                var targetHeight: CGFloat = 0
                
                if size.width < size.height {
                    targetWidth = targetDimension
                    targetHeight = targetWidth / aspectRatio
                } else {
                    targetHeight = targetDimension
                    targetWidth = targetHeight * aspectRatio
                }
                
                targetSize = CGSize(width: targetWidth, height: targetHeight)
            }
        }
        
        let pathMD5 = Utility.getMD5(path)
        let compressionUrl = Utility.getPathUrl("\(Utility.basePath())/\(pathMD5).\(sourceVideoType)")
        
        let timescale = sourceVideoAsset.duration.timescale
        let minStartTime = startTime ?? 0
        
        let videoDuration = sourceVideoAsset.duration.seconds * 1000
        let minDuration = duration ?? videoDuration
        let maxDurationTime = min(minStartTime + minDuration, videoDuration)
        
        let cmStartTime = CMTime(seconds: minStartTime / 1000.0, preferredTimescale: timescale)
        let cmDurationTime = CMTime(seconds: maxDurationTime / 1000.0, preferredTimescale: timescale)
        let timeRange = CMTimeRange(start: cmStartTime, duration: cmDurationTime)
        
        let isIncludeAudio = includeAudio ?? true
        let session = getComposition(isIncludeAudio, timeRange, sourceVideoTrack)

        let exporter = AVAssetExportSession(asset: session, presetName: AVAssetExportPresetPassthrough)!

        exporter.outputURL = compressionUrl
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        exporter.timeRange = timeRange

        if let size = targetSize {
            let videoComposition = AVMutableVideoComposition(propertiesOf: sourceVideoAsset)
            videoComposition.renderSize = size

            if !transform.isIdentity {
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: .zero, duration: sourceVideoAsset.duration)

                let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: sourceVideoTrack)
                transformer.setTransform(transform, at: .zero)

                instruction.layerInstructions = [transformer]
                videoComposition.instructions = [instruction]
            }

            if let frameRate = frameRate {
                videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(frameRate))
            }

            exporter.videoComposition = videoComposition
        }

        Utility.deleteFile(compressionUrl.absoluteString)

        // Timer 必须在主线程创建
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateProgress),
                                             userInfo: ["exporter": exporter, "unique": unique], repeats: true)

            exporter.exportAsynchronously {
                timer.invalidate()

                if self.stopCommand {
                    self.stopCommand = false
                    var json = self.getMediaInfoJson(path)
                    json["isCancel"] = true
                    let jsonString = Utility.keyValueToJson(json)
                    result(jsonString)
                    return
                }

                if deleteOrigin {
                    try? FileManager.default.removeItem(atPath: path)
                }

                var json = self.getMediaInfoJson(Utility.excludeEncoding(compressionUrl.path))
                json["isCancel"] = false
                let jsonString = Utility.keyValueToJson(json)
                result(jsonString)
            }

            self.exporter = exporter
        }
    }
    
    private func cancelCompression(_ result: FlutterResult) {
        stopCommand = true
        exporter?.cancelExport()
        result("")
    }
}
