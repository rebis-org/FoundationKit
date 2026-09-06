public import ErrKit
public import Foundation

public enum FileSystemError: Error, LocalizedError {
    case pathNotFound(path: String)
    case emptyFilePath
    case cannotRenameRoot
    case renameFailed(path: String, underlying: any Error)
    case moveFailed(path: String, underlying: any Error)
    case copyFailed(path: String, underlying: any Error)
    case deleteFailed(path: String, underlying: any Error)
    case unresolvedSearchPath(
        FileManager.SearchPathDirectory, domain: FileManager.SearchPathDomainMask,
    )
    case emptyWritePath
    case directoryCreationFailed(path: String, underlying: any Error)
    case fileCreationFailed(path: String)
    case writeFailed(path: String, underlying: any Error)
    case stringEncodingFailed(String)
    case readFailed(path: String, underlying: any Error)
    case stringDecodingFailed(path: String)
    case notAnInt(path: String, value: String)
    case cannotOpenDirectory(URL)
    case insufficientPermissions(URL)
    case directoryNotFound(URL)
    case systemResourcesUnavailable
    case invalidConfiguration(String)
    case tooManyWatchers(limit: Int)
    case failedToWatch(URL, underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case let .pathNotFound(path): failure("find path", path)
        case .emptyFilePath: failure("use empty file path")
        case .cannotRenameRoot: failure("rename file-system root")
        case let .renameFailed(path, error): failure("rename", path, because: error)
        case let .moveFailed(path, error): failure("move", path, because: error)
        case let .copyFailed(path, error): failure("copy", path, because: error)
        case let .deleteFailed(path, error): failure("delete", path, because: error)

        case let .unresolvedSearchPath(searchPath, domain):
            failure("resolve search path \(searchPath) in domain \(domain)")

        case .emptyWritePath: failure("write to empty path")
        case let .directoryCreationFailed(path, error): failure("create directory", path, because: error)
        case let .fileCreationFailed(path): failure("create file", path)
        case let .writeFailed(path, error): failure("write", path, because: error)
        case let .stringEncodingFailed(string): failure("encode string", string)
        case let .readFailed(path, error): failure("read", path, because: error)
        case let .stringDecodingFailed(path): failure("decode string at", path)
        case let .notAnInt(path, value): failure("parse integer from", path, because: "'\(value)'")
        case let .cannotOpenDirectory(url): failure("open directory", url.path)

        case let .insufficientPermissions(url):
            failure("watch", url.path, because: "insufficient permissions")

        case let .directoryNotFound(url): failure("find directory", url.path)

        case .systemResourcesUnavailable:
            failure("allocate system resources", because: "unavailable for file-system watching")

        case let .invalidConfiguration(message): failure("configure watcher", because: message)

        case let .tooManyWatchers(limit):
            failure("watch directory", because: "maximum \(limit) watched directories reached")

        case let .failedToWatch(url, error): failure("watch", url.path, because: error)
        }
    }

    public var snapshot: ErrSnapshot {
        ErrSnapshot(error: self)
    }
}
