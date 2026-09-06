public import Foundation
public import InfraKit
public import UniformTypeIdentifiers

public extension InfraKit.Predicate where A == URL {
    static func fileExtensions(_ extensions: [String]) -> Self {
        let set = Set(extensions.map { $0.lowercased() })
        return Self { set.contains($0.pathExtension.lowercased()) }
    }

    private static let utTypeCache = Locked([String: UTType?]())

    static func utTypes(_ types: [UTType]) -> Self {
        Self { url in
            let ext = url.pathExtension
            guard
                let fileType = utTypeCache.withLock({ cache -> UTType? in
                    if let cached = cache[ext] {
                        return cached
                    }
                    let resolved = UTType(filenameExtension: ext)
                    cache[ext] = resolved
                    return resolved
                })
            else { return false }
            return types.contains { $0.conforms(to: fileType) || fileType.conforms(to: $0) }
        }
    }

    static var imageFiles: Self {
        utTypes([.png, .jpeg, .webP, .heic, .heif, .tiff, .gif, .bmp, .ico, .icns])
    }

    static var videoFiles: Self {
        utTypes([.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi])
    }

    static var audioFiles: Self {
        utTypes([.audio, .mp3, .mpeg4Audio, .wav, .aiff])
    }

    static var documentFiles: Self {
        utTypes([.pdf, .rtf, .plainText, .html, .xml, .yaml, .json])
    }

    static func fileName(matching pattern: String) -> Self {
        // Compiled once here instead of per evaluation; an invalid
        // pattern never matches, matching range(of:.regularExpression).
        let compiled = try? NSRegularExpression(pattern: pattern)
        return fileName { name in
            guard let compiled else { return false }
            return compiled.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil
        }
    }

    static func fileName(startingWith prefix: String) -> Self {
        fileName { $0.starts(with: prefix) }
    }

    static func fileName(endingWith suffix: String) -> Self {
        fileName { $0.hasSuffix(suffix) }
    }

    static func fileName(containing substring: String) -> Self {
        fileName { $0.contains(substring) }
    }

    static func fileName(localizedStandardContaining substring: String) -> Self {
        fileName { $0.localizedStandardContains(substring) }
    }

    static func fileName(localizedCaseInsensitiveContaining substring: String) -> Self {
        fileName { $0.localizedCaseInsensitiveContains(substring) }
    }

    private static func fileName(where test: @escaping @Sendable (String) -> Bool) -> Self {
        Self { test($0.lastPathComponent) }
    }

    static func fileSize(_ range: ClosedRange<Int>) -> Self {
        Self { url in
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                return false
            }
            return range.contains(size)
        }
    }

    static func modifiedWithin(_ interval: TimeInterval) -> Self {
        Self { url in
            guard
                let date = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
            else {
                return false
            }
            return Date().timeIntervalSince(date) <= interval
        }
    }

    static var directory: Self {
        Self { isDirectory($0) == true }
    }

    static var file: Self {
        Self { isDirectory($0) == false }
    }

    private static func isDirectory(_ url: URL) -> Bool? {
        try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
    }
}
