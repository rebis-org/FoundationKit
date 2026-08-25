public import Foundation
public import PathKit
import Darwin

/// FileManager is not Sendable, so this class is unchecked; the instance is immutable and FileManager is documented as thread-safe.
public final class FoundationVolume: Volume, @unchecked Sendable {
    private let manager: FileManager

    public init(manager: FileManager = .default) {
        self.manager = manager
    }

    public func exists(at path: Path) -> Bool {
        manager.fileExists(atPath: path.string)
    }

    public func attributes(at path: Path) -> [FileAttributeKey: Any] {
        (try? manager.attributesOfItem(atPath: path.string)) ?? [:]
    }

    public func type(at path: Path) -> EntryType? {
        var buffer = stat()
        guard unsafe Darwin.lstat(path.string, &buffer) == 0 else { return nil }
        switch buffer.st_mode & S_IFMT {
        case S_IFLNK: return .symlink
        case S_IFDIR: return .directory
        default: return .file
        }
    }

    public func data(at path: Path) throws -> Data {
        do {
            return try Data(contentsOf: path.url)
        } catch {
            throw FileSystemError.readFailed(path: path.string, underlying: error)
        }
    }

    public func write(_ data: Data, at path: Path) throws {
        do {
            try data.write(to: path.url)
        } catch {
            throw FileSystemError.writeFailed(path: path.string, underlying: error)
        }
    }

    public func createFile(at path: Path, contents: Data?) throws {
        guard manager.createFile(atPath: path.string, contents: contents) else {
            throw FileSystemError.fileCreationFailed(path: path.string)
        }
    }

    public func createDirectory(at path: Path, createIntermediateDirectories: Bool) throws {
        do {
            try manager.createDirectory(at: path.url, withIntermediateDirectories: createIntermediateDirectories)
        } catch CocoaError.Code.fileWriteFileExists {
            return
        } catch {
            throw FileSystemError.directoryCreationFailed(path: path.string, underlying: error)
        }
    }

    public func symlink(_ target: Path, at path: Path) throws {
        do {
            try manager.createSymbolicLink(atPath: path.string, withDestinationPath: target.string)
        } catch {
            throw FileSystemError.writeFailed(path: path.string, underlying: error)
        }
    }

    public func symlinkTarget(at path: Path) throws -> Path {
        do {
            let destination = try manager.destinationOfSymbolicLink(atPath: path.string)
            return Path(destination) ?? path.parent / destination
        } catch CocoaError.fileReadUnknown {
            return path
        } catch {
            throw FileSystemError.readFailed(path: path.string, underlying: error)
        }
    }

    public func resolve(at path: Path) throws -> Path {
        guard let pointer = unsafe Darwin.realpath(path.string, nil) else {
            throw FileSystemError.pathNotFound(path: path.string)
        }
        defer { unsafe Darwin.free(pointer) }
        guard let resolved = unsafe String(validatingCString: pointer) else {
            throw FileSystemError.readFailed(
                path: path.string, underlying: CocoaError.error(.fileReadUnknownStringEncoding),
            )
        }
        return Path(string: (resolved as NSString).standardizingPath)
    }

    public func copy(from source: Path, to destination: Path) throws {
        do {
            try manager.copyItem(at: source.url, to: destination.url)
        } catch {
            throw FileSystemError.copyFailed(path: source.string, underlying: error)
        }
    }

    public func move(from source: Path, to destination: Path) throws {
        do {
            try manager.moveItem(at: source.url, to: destination.url)
        } catch {
            throw FileSystemError.moveFailed(path: source.string, underlying: error)
        }
    }

    public func delete(at path: Path) throws {
        guard exists(at: path) else { return }
        do {
            try manager.removeItem(at: path.url)
        } catch {
            throw FileSystemError.deleteFailed(path: path.string, underlying: error)
        }
    }

    public func children(of path: Path, includingHidden: Bool) throws -> [Path] {
        let urls = try manager.contentsOfDirectory(at: path.url, includingPropertiesForKeys: nil)
        return urls.compactMap { url in
            guard let child = Path(url.path), includingHidden || !child.baseName().hasPrefix(".") else {
                return nil
            }
            return child
        }
    }

    public func setAttributes(_ attributes: [FileAttributeKey: Any], at path: Path) throws {
        try manager.setAttributes(attributes, ofItemAtPath: path.string)
    }

    public func enumerator(at path: Path) -> FileManager.DirectoryEnumerator? {
        manager.enumerator(at: path.url, includingPropertiesForKeys: [.isDirectoryKey])
    }
}
