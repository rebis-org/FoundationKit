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
        case let .pathNotFound(path): "Path not found: \(path)"
        case .emptyFilePath: "The file path is empty"
        case .cannotRenameRoot: "Cannot rename the file-system root"

        case let .renameFailed(path, error):
            "Failed to rename '\(path)': \(error.localizedDescription)"

        case let .moveFailed(path, error): "Failed to move '\(path)': \(error.localizedDescription)"
        case let .copyFailed(path, error): "Failed to copy '\(path)': \(error.localizedDescription)"

        case let .deleteFailed(path, error):
            "Failed to delete '\(path)': \(error.localizedDescription)"

        case let .unresolvedSearchPath(searchPath, domain):
            "Cannot resolve search path \(searchPath) in domain \(domain)"

        case .emptyWritePath: "The write path is empty"

        case let .directoryCreationFailed(path, error):
            "Failed to create directory '\(path)': \(error.localizedDescription)"

        case let .fileCreationFailed(path): "Failed to create file '\(path)'"

        case let .writeFailed(path, error):
            "Failed to write '\(path)': \(error.localizedDescription)"

        case let .stringEncodingFailed(string): "Failed to encode string: \(string)"
        case let .readFailed(path, error): "Failed to read '\(path)': \(error.localizedDescription)"
        case let .stringDecodingFailed(path): "Failed to decode string at '\(path)'"
        case let .notAnInt(path, value): "File '\(path)' does not contain an integer: '\(value)'"
        case let .cannotOpenDirectory(url): "Cannot open directory at \(url.path)"
        case let .insufficientPermissions(url): "Insufficient permissions to watch \(url.path)"
        case let .directoryNotFound(url): "Directory not found at \(url.path)"
        case .systemResourcesUnavailable: "System resources unavailable for file-system watching"
        case let .invalidConfiguration(message): "Invalid watcher option: \(message)"
        case let .tooManyWatchers(limit): "Reached the maximum number of watched directories (\(limit))"

        case let .failedToWatch(url, error):
            "Failed to watch \(url.path): \(error.localizedDescription)"
        }
    }

    public var snapshot: ErrSnapshot {
        ErrSnapshot(error: self)
    }
}
