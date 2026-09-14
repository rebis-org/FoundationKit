public import Foundation
public import PathKit
import LogKit

private let fileKitLogger: Log<OSLogSink> = .osLog(subsystem: "dev.rebis.FileKit", category: "io")

extension Item {
    public func exists(using volume: some Volume = FoundationVolume()) -> Bool {
        volume.exists(at: Path(self))
    }

    public func type(using volume: some Volume = FoundationVolume()) -> EntryType? {
        volume.type(at: Path(self))
    }

    public var isDirectory: Bool {
        type() == .directory
    }

    public var isFile: Bool {
        exists() && !isDirectory
    }

    public func copy(to destination: some Item, overwrite: Bool = false, using volume: some Volume = FoundationVolume()) throws -> Path {
        let destinationPath = Path(destination)
        if overwrite, volume.type(at: Path(self)) != .directory {
            try removeForOverwrite(at: destinationPath, using: volume)
        }
        try volume.copy(from: Path(self), to: destinationPath)
        return destinationPath
    }

    public func copy(into directory: some Item, overwrite: Bool = false, using volume: some Volume = FoundationVolume()) throws -> Path {
        let directoryPath = Path(directory)
        try ensureDirectory(at: directoryPath, using: volume)
        let result = directoryPath / baseName()
        if overwrite {
            try removeForOverwrite(at: result, using: volume)
        }
        try volume.copy(from: Path(self), to: result)
        return result
    }

    public func move(to destination: some Item, overwrite: Bool = false, using volume: some Volume = FoundationVolume()) throws -> Path {
        let destinationPath = Path(destination)
        if overwrite {
            try removeForOverwrite(at: destinationPath, using: volume)
        }
        try volume.move(from: Path(self), to: destinationPath)
        return destinationPath
    }

    public func move(into directory: some Item, overwrite: Bool = false, using volume: some Volume = FoundationVolume()) throws -> Path {
        let directoryPath = Path(directory)
        try ensureDirectory(at: directoryPath, using: volume)
        guard volume.type(at: directoryPath) == .directory else {
            throw FileSystemError.copyFailed(
                path: directoryPath.string, underlying: CocoaError.error(.fileWriteFileExists),
            )
        }
        let result = directoryPath / baseName()
        if overwrite {
            try removeForOverwrite(at: result, using: volume)
        }
        try volume.move(from: Path(self), to: result)
        return result
    }

    public func delete(using volume: some Volume = FoundationVolume()) throws {
        try volume.delete(at: Path(self))
    }

    public func touch(using volume: some Volume = FoundationVolume()) throws -> Path {
        let path = Path(self)
        if volume.exists(at: path) {
            try volume.setAttributes([.modificationDate: Date()], at: path)
        } else {
            try volume.createFile(at: path, contents: nil)
        }
        return path
    }

    public func makeDirectory(
        options: MakeDirectoryOption? = nil, using volume: some Volume = FoundationVolume(),
    ) throws -> Path {
        let path = Path(self)
        try volume.createDirectory(at: path, createIntermediateDirectories: options == .createIntermediateDirectories)
        return path
    }

    public func rename(to newName: String, using volume: some Volume = FoundationVolume()) throws -> Path {
        let newPath = parent / newName
        try volume.move(from: Path(self), to: newPath)
        return newPath
    }

    public func symlink(as destination: some Item, using volume: some Volume = FoundationVolume()) throws -> Path {
        let destinationPath = Path(destination)
        try volume.symlink(Path(self), at: destinationPath)
        return destinationPath
    }

    public func symlink(into directory: some Item, using volume: some Volume = FoundationVolume()) throws -> Path {
        let directoryPath = Path(directory)
        switch volume.type(at: directoryPath) {
        case .none, .symlink:
            try volume.createDirectory(at: directoryPath, createIntermediateDirectories: true)

        case .file:
            throw FileSystemError.writeFailed(
                path: directoryPath.string, underlying: CocoaError.error(.fileWriteFileExists),
            )

        case .directory:
            break
        }
        let destination = directoryPath / baseName()
        try volume.symlink(Path(self), at: destination)
        return destination
    }

    public func symlinkTarget(using volume: some Volume = FoundationVolume()) throws -> Path {
        try volume.symlinkTarget(at: Path(self))
    }

    public func resolve(using volume: some Volume = FoundationVolume()) throws -> Path {
        try volume.resolve(at: Path(self))
    }

    public func list(
        options: ListDirectoryOption? = nil, using volume: some Volume = FoundationVolume(),
    ) -> [Path] {
        guard
            let paths = try? volume.children(
                of: Path(self), includingHidden: options == .includeHidden || options == .includeHiddenUnsorted,
            )
        else {
            fileKitLogger.warning("Could not list directory", context: ["path": Path(self).string])
            return []
        }
        let sorted = options != .unsorted && options != .includeHiddenUnsorted
        return sorted ? paths.sorted() : paths
    }

    public func probe(using volume: some Volume = FoundationVolume()) -> Probe {
        Probe(root: Path(self), volume: volume)
    }

    public var creationDate: Date? {
        FoundationVolume().attributes(at: Path(self))[.creationDate] as? Date
    }

    public var modificationDate: Date? {
        FoundationVolume().attributes(at: Path(self))[.modificationDate] as? Date
    }

    @discardableResult
    public func setPermissions(_ permissions: Int, using volume: some Volume = FoundationVolume()) throws -> Path {
        let path = Path(self)
        try volume.setAttributes([.posixPermissions: permissions], at: path)
        return path
    }

    @discardableResult
    public func lock(using volume: some Volume = FoundationVolume()) throws -> Path {
        let path = Path(self)
        var attrs = volume.attributes(at: path)
        if attrs[.immutable] as? Bool != true {
            attrs[.immutable] = true
            try volume.setAttributes(attrs, at: path)
        }
        return path
    }

    @discardableResult
    public func unlock(using volume: some Volume = FoundationVolume()) throws -> Path {
        let path = Path(self)
        let attrs = volume.attributes(at: path)
        if attrs.isEmpty {
            return path
        }
        if attrs[.immutable] as? Bool == true {
            var mutable = attrs
            mutable[.immutable] = false
            try volume.setAttributes(mutable, at: path)
        }
        return path
    }
}

public enum MakeDirectoryOption: Sendable {
    case createIntermediateDirectories
}

public enum ListDirectoryOption: Sendable {
    case includeHidden, includeHiddenUnsorted, unsorted
}

private func ensureDirectory(at path: Path, using volume: some Volume) throws {
    if !volume.exists(at: path) {
        try volume.createDirectory(at: path, createIntermediateDirectories: true)
    }
}

private func removeForOverwrite(at path: Path, using volume: some Volume) throws {
    if let kind = volume.type(at: path), kind != .directory {
        try volume.delete(at: path)
    }
}

extension [Path] {
    public var directories: [Path] {
        filter(\.isDirectory)
    }

    public var files: [Path] {
        filter { [.file, .symlink].contains($0.type()) }
    }
}
