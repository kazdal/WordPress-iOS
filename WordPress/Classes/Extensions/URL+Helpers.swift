import Foundation
import MobileCoreServices

extension URL {

    /// The URLResource fileSize of the file at the URL in bytes, if available.
    ///
    var fileSize: Int64? {
        guard isFileURL else {
            return nil
        }
        let values = try? resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values?.allValues[.fileSizeKey] as? NSNumber else {
            return nil
        }
        return fileSize.int64Value
    }

    /// The URLResource uniform type identifier for the file at the URL, if available.
    ///
    var typeIdentifier: String? {
        let values = try? resourceValues(forKeys: [.typeIdentifierKey])
        return values?.typeIdentifier
    }

    var typeIdentifierFileExtension: String? {
        guard let type = typeIdentifier else {
            return nil
        }
        return URL.fileExtensionForUTType(type)
    }

    /// Returns a URL with an incremental file name, if a file already exists at the given URL.
    ///
    /// Previously seen in MediaService.m within urlForMediaWithFilename:andExtension:
    ///
    func incrementalFilename() -> URL {
        var url = self
        let pathExtension = url.pathExtension
        let filename = url.deletingPathExtension().lastPathComponent
        var index = 1
        let fileManager = FileManager.default
        while fileManager.fileExists(atPath: url.path) {
            let incrementedName = "\(filename)-\(index)"
            url.deleteLastPathComponent()
            url.appendPathComponent(incrementedName, isDirectory: false)
            url.appendPathExtension(pathExtension)
            index += 1
        }
        return url
    }

    /// The expected file extension string for a given UTType identifier string.
    ///
    /// - param type: The UTType identifier string.
    /// - returns: The expected file extension or nil if unknown.
    ///
    static func fileExtensionForUTType(_ type: String) -> String? {
        let fileExtension = UTTypeCopyPreferredTagWithClass(type as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue()
        return fileExtension as String?
    }

    var pixelSize: CGSize {
        get {
            if isVideo {
                let asset = AVAsset(url: self as URL)
                if let track = asset.tracks(withMediaType: .video).first {
                    return track.naturalSize.applying(track.preferredTransform)
                }
            } else if isImage {
                let options: [NSString: NSObject] = [kCGImageSourceShouldCache: false as CFBoolean]
                if
                    let imageSource = CGImageSourceCreateWithURL(self as NSURL, nil),
                    let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, options as CFDictionary?) as NSDictionary?,
                    let pixelWidth = imageProperties[kCGImagePropertyPixelWidth as NSString] as? Int,
                    let pixelHeight = imageProperties[kCGImagePropertyPixelHeight as NSString] as? Int
                {
                    return CGSize(width: pixelWidth, height: pixelHeight)
                }
            }
            return CGSize.zero
        }
    }

    var mimeType: String {
        guard let uti = typeIdentifier,
            let mimeType = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType)?.takeUnretainedValue() as String?
            else {
                return "application/octet-stream"
        }

        return mimeType
    }

    var isVideo: Bool {
        guard let uti = typeIdentifier else {
            return false
        }

        return UTTypeConformsTo(uti as CFString, kUTTypeMovie)
    }

    var isImage: Bool {
        guard let uti = typeIdentifier else {
            return false
        }

        return UTTypeConformsTo(uti as CFString, kUTTypeImage)
    }

    var isGif: Bool {
        if let uti = typeIdentifier {
            return UTTypeConformsTo(uti as CFString, kUTTypeGIF)
        } else {
            return pathExtension.lowercased() == "gif"
        }
    }

    func appendingHideMasterbarParameters() -> URL? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        // FIXME: This code is commented out because of a menu navigation issue that can occur while
        // viewing a site within the webview. See https://github.com/wordpress-mobile/WordPress-iOS/issues/9796
        // for more details.
        //
        // var queryItems = components.queryItems ?? []
        // queryItems.append(URLQueryItem(name: "preview", value: "true"))
        // queryItems.append(URLQueryItem(name: "iframe", value: "true"))
        // components.queryItems = queryItems
        /////
        return components.url
    }

    var hasWordPressDotComHostname: Bool {
        guard let host = host else {
            return false
        }

        return host.hasSuffix(".wordpress.com")
    }

    var isWordPressDotComPost: Bool {
        // year, month, day, slug
        let components = pathComponents.filter({ $0 != "/" })
        return components.count == 4 && hasWordPressDotComHostname
    }
    
    func refreshLocalPath() -> URL? {
        guard isFileURL else {
            return self
        }
        
        let nsString = absoluteString as NSString
        let results = absoluteString.matches(regex: "[0-9a-fA-F]{8}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{12}")
        let uuids = results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
        
        let nsString2 = FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask).first!.absoluteString as NSString
        let results2 = FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask).first!.absoluteString.matches(regex: "[0-9a-fA-F]{8}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{4}\\-[0-9a-fA-F]{12}")
        let uuids2 = results2.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString2.substring(with: result.range(at: $0))
                    : ""
            }
        }
        
        var finalUrl = absoluteString
        
        for (index, uuid) in uuids.enumerated() {
            finalUrl = finalUrl.replacingOccurrences(of: uuid.first!, with: uuids2[index].first!)
        }
        
        return URL(string: finalUrl)
    }
}

extension NSURL {
    @objc var isVideo: Bool {
        return (self as URL).isVideo
    }

    @objc var fileSize: NSNumber? {
        guard let fileSize = (self as URL).fileSize else {
            return nil
        }
        return NSNumber(value: fileSize)
    }

    @objc func appendingHideMasterbarParameters() -> NSURL? {
        let url = self as URL
        return url.appendingHideMasterbarParameters() as NSURL?
    }
}

extension URL {
    func appendingLocale() -> URL {
        guard let selfComponents = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
                return self
        }

        let localeIdentifier = Locale.current.identifier

        var newComponents = URLComponents()
        newComponents.scheme = selfComponents.scheme
        newComponents.host = selfComponents.host
        newComponents.path = selfComponents.path

        var selfQueryItems = selfComponents.queryItems ?? []

        let localeQueryItem = URLQueryItem(name: "locale", value: localeIdentifier)
        selfQueryItems.append(localeQueryItem)

        newComponents.queryItems = selfQueryItems

        return newComponents.url ?? self
    }
}
