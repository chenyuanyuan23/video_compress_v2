import Foundation
import CommonCrypto

class Utility: NSObject {
    static let fileManager = FileManager.default
    
    static func basePath()->String {
        let path = "\(NSTemporaryDirectory())video_compress"
        do {
            if !fileManager.fileExists(atPath: path) {
                try! fileManager.createDirectory(atPath: path,
                                                 withIntermediateDirectories: true, attributes: nil)
            }
        }
        return path
    }
    
    static func stripFileExtension(_ fileName:String)->String {
        var components = fileName.components(separatedBy: ".")
        if components.count > 1 {
            components.removeLast()
            return components.joined(separator: ".")
        } else {
            return fileName
        }
    }
    static func getFileName(_ path: String)->String {
        return stripFileExtension((path as NSString).lastPathComponent)
    }
    
    static func getPathUrl(_ path: String)->URL {
        return URL(fileURLWithPath: excludeFileProtocol(path))
    }
    
    static func getMD5(_ string: String) -> String {
        let data = string.data(using: .utf8)!
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    static func excludeFileProtocol(_ path: String)->String {
        return path.replacingOccurrences(of: "file://", with: "")
    }
    
    static func excludeEncoding(_ path: String) -> String{
        return path.removingPercentEncoding!
    }
    
    static func keyValueToJson(_ keyAndValue: [String : Any?])->String {
        let data = try! JSONSerialization.data(withJSONObject: keyAndValue as NSDictionary, options: [])
        let jsonString = NSString(data:data as Data,encoding: String.Encoding.utf8.rawValue)
        return jsonString! as String
    }
    
    static func deleteFile(_ path: String, clear: Bool = false) {
        let url = getPathUrl(path)
        if fileManager.fileExists(atPath: url.absoluteString) {
            try? fileManager.removeItem(at: url)
        }
        if clear {
            try? fileManager.removeItem(at: url)
        }
    }
}
