public import Foundation
public import InfraKit
public import UniformTypeIdentifiers

public extension InfraKit.Predicate where A == URL {
    static func fileExtensions(_ extensions: [String]) -> Self {
        Self { url in
            extensions.contains(url.pathExtension.lowercased())
        }
    }

    static func utTypes(_ types: [UTType]) -> Self {
        Self { url in
            guard let fileType = UTType(filenameExtension: url.pathExtension) else { return false }
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
        Self { url in
            url.lastPathComponent.range(of: pattern, options: .regularExpression) != nil
        }
    }

    static func fileName(startingWith prefix: String) -> Self {
        Self { url in
            url.lastPathComponent.starts(with: prefix)
        }
    }

    static func fileName(endingWith suffix: String) -> Self {
        Self { url in
            url.lastPathComponent.hasSuffix(suffix)
        }
    }

    static func fileName(containing substring: String) -> Self {
        Self { url in
            url.lastPathComponent.contains(substring)
        }
    }

    static func fileName(localizedStandardContaining substring: String) -> Self {
        Self { url in
            url.lastPathComponent.localizedStandardContains(substring)
        }
    }

    static func fileName(localizedCaseInsensitiveContaining substring: String) -> Self {
        Self { url in
            url.lastPathComponent.localizedCaseInsensitiveContains(substring)
        }
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
        Self { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    static var file: Self {
        Self { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == false
        }
    }
}
