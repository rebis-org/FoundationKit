public import Foundation
public import PathKit

public extension Node where Kind == DirectoryKind {
    static var current: Directory {
        try! Directory(
            path: Path(string: FileManager.default.currentDirectoryPath), volume: FoundationVolume(),
        )
    }

    static var root: Directory {
        try! Directory(path: Path(string: "/"), volume: FoundationVolume())
    }

    static var home: Directory {
        try! Directory(path: Path.home, volume: FoundationVolume())
    }

    static var temporary: Directory {
        try! Directory(path: Path(string: NSTemporaryDirectory()), volume: FoundationVolume())
    }

    func subdirectory(at path: String) throws -> Directory {
        try Directory(path: self.path / path, volume: volume)
    }

    func file(at path: String) throws -> File {
        try File(path: self.path / path, volume: volume)
    }

    func createSubdirectory(at path: String) throws -> Directory {
        let newPath = self.path / path
        try volume.createDirectory(at: newPath, createIntermediateDirectories: true)
        return try Directory(path: newPath, volume: volume)
    }

    func createFile(at path: String, contents: Data? = nil) throws -> File {
        let newPath = self.path / path
        try volume.createFile(at: newPath, contents: contents)
        return try File(path: newPath, volume: volume)
    }

    func children(includingHidden: Bool = false) throws -> [Path] {
        try volume.children(of: path, includingHidden: includingHidden)
    }

    func moveContents(to directory: Directory, includingHidden: Bool = false) throws {
        for child in try children(includingHidden: includingHidden) {
            switch volume.type(at: child) {
            case .directory: try Directory(path: child, volume: volume).move(to: directory)
            default: try File(path: child, volume: volume).move(to: directory)
            }
        }
    }

    func empty(includingHidden includeHidden: Bool = false) throws {
        for child in try children(includingHidden: includeHidden) {
            if volume.type(at: child) == .directory {
                try Directory(path: child, volume: volume).empty(includingHidden: includeHidden)
            }
            try volume.delete(at: child)
        }
    }

    func isEmpty(includingHidden includeHidden: Bool = false) -> Bool {
        (try? children(includingHidden: includeHidden).isEmpty) ?? false
    }
}

#if os(iOS) || os(tvOS) || os(macOS)
    public extension Node where Kind == DirectoryKind {
        static func matching(
            _ searchPath: FileManager.SearchPathDirectory,
            in domain: FileManager.SearchPathDomainMask = .userDomainMask,
            resolvedBy manager: FileManager = .default,
        ) throws -> Directory {
            let urls = manager.urls(for: searchPath, in: domain)
            guard let match = urls.first else {
                throw FileSystemError.unresolvedSearchPath(searchPath, domain: domain)
            }
            return try Directory(
                path: Path(match.relativePath) ?? Path(string: match.relativePath),
                volume: FoundationVolume(manager: manager),
            )
        }

        static var documents: Directory? {
            try? matching(.documentDirectory)
        }

        static var library: Directory? {
            try? matching(.libraryDirectory)
        }
    }
#endif
