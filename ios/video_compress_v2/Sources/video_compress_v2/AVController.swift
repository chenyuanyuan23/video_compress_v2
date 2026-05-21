
import AVFoundation
import MobileCoreServices

class AvController: NSObject {

    private let backgroundQueue = DispatchQueue(label: "com.video_compress.avcontroller", qos: .userInitiated)

    public func getVideoAsset(_ url:URL)->AVURLAsset {
        return AVURLAsset(url: url)
    }

    /// 异步获取视频轨道 (推荐使用)
    public func getTrack(_ asset: AVURLAsset, completion: @escaping (AVAssetTrack?) -> Void) {
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "tracks", error: &error)
            if status == .loaded {
                completion(asset.tracks(withMediaType: AVMediaType.video).first)
            } else {
                completion(nil)
            }
        }
    }

    /// 同步获取视频轨道 - 在后台线程执行，避免阻塞主线程
    /// 注意：调用此方法时应确保不在主线程，或使用 backgroundQueue 包装
    public func getTrack(_ asset: AVURLAsset)->AVAssetTrack? {
        var track: AVAssetTrack? = nil
        let semaphore = DispatchSemaphore(value: 0)

        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "tracks", error: &error)
            if status == .loaded {
                track = asset.tracks(withMediaType: AVMediaType.video).first
            }
            semaphore.signal()
        }

        // 如果在主线程调用，使用超时防止死锁
        if Thread.isMainThread {
            _ = semaphore.wait(timeout: .now() + 10.0)
        } else {
            semaphore.wait()
        }

        return track
    }

    /// 在后台线程安全执行同步获取轨道操作
    public func getTrackOnBackground(_ asset: AVURLAsset, completion: @escaping (AVAssetTrack?) -> Void) {
        backgroundQueue.async { [weak self] in
            let track = self?.getTrack(asset)
            DispatchQueue.main.async {
                completion(track)
            }
        }
    }

    /// 根据 track 计算视频方向 (复用已有 track，避免重复创建 asset)
    public func getVideoOrientation(from track: AVAssetTrack) -> Int {
        let size = track.naturalSize
        let txf = track.preferredTransform
        if size.width == txf.tx && size.height == txf.ty {
            return 0
        } else if txf.tx == 0 && txf.ty == 0 {
            return 90
        } else if txf.tx == 0 && txf.ty == size.width {
            return 180
        } else {
            return 270
        }
    }

    /// 根据路径获取视频方向 (会创建新的 asset，尽量使用 getVideoOrientation(from:) 复用)
    public func getVideoOrientation(_ path: String) -> Int? {
        let url = Utility.getPathUrl(path)
        let asset = getVideoAsset(url)
        guard let track = getTrack(asset) else {
            return nil
        }
        return getVideoOrientation(from: track)
    }

    public func getMetaDataByTag(_ asset:AVAsset,key:String)->String {
        for item in asset.commonMetadata {
            if item.commonKey?.rawValue == key {
                return item.stringValue ?? "";
            }
        }
        return ""
    }
}