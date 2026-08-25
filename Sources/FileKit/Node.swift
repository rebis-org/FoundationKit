public import Foundation
public import PathKit

public protocol NodeKind: Sendable {
    static func validate(_ path: inout Path, in volume: any Volume) throws
}

public enum FileKind: NodeKind {
    public static func validate(_ path: inout Path, in volume: any Volume) throws {
        guard volume.type(at: path) != .directory else {
            throw FileSystemError.pathNotFound(path: path.string)
        }
    }
}

public enum DirectoryKind: NodeKind {
    public static func validate(_ path: inout Path, in volume: any Volume) throws {
        if !path.string.hasSuffix("/") {
            path = Path(string: path.string + "/")
        }
        let type = volume.type(at: path)
        guard type == .directory || type == .symlink else {
            throw FileSystemError.pathNotFound(path: path.string)
        }
    }
}

public struct Node<Kind: NodeKind>: Sendable {
    public let path: Path
    public let volume: any Volume

    public init(path: some Item, volume: any Volume) throws {
        var path = Path(path)
        try Kind.validate(&path, in: volume)
        self.path = path
        self.volume = volume
    }
}

public typealias File = Node<FileKind>
public typealias Directory = Node<DirectoryKind>

public extension Node {
    var url: URL {
        path.url
    }

    var name: String {
        path.baseName()
    }

    var `extension`: String {
        path.extension
    }

    var nameExcludingExtension: String {
        let components = name.split(separator: ".")
        return components.count > 1 ? components.dropLast().joined() : name
    }

    var parent: Directory? {
        try? Directory(path: path.parent, volume: volume)
    }

    func path(relativeTo directory: Directory) -> String {
        path.relative(to: directory.path)
    }

    @discardableResult
    func rename(to newName: String, keepExtension: Bool = true) throws -> Node {
        guard let parent else { throw FileSystemError.cannotRenameRoot }
        var finalName = newName
        if keepExtension, !`extension`.isEmpty {
            finalName = finalName.hasSuffix(".\(`extension`)") ? finalName : "\(finalName).\(`extension`)"
        }
        let newPath = parent.path / finalName
        try volume.move(from: path, to: newPath)
        return try Node(path: newPath, volume: volume)
    }

    @discardableResult
    func move(to directory: Directory) throws -> Node {
        let newPath = directory.path / name
        try volume.move(from: path, to: newPath)
        return try Node(path: newPath, volume: volume)
    }

    @discardableResult
    func copy(to directory: Directory) throws -> Node {
        let newPath = directory.path / name
        try volume.copy(from: path, to: newPath)
        return try Node(path: newPath, volume: volume)
    }

    func delete() throws {
        try volume.delete(at: path)
    }

    var creationDate: Date? {
        volume.attributes(at: path)[.creationDate] as? Date
    }

    var modificationDate: Date? {
        volume.attributes(at: path)[.modificationDate] as? Date
    }
}

extension Node: CustomStringConvertible {
    public var description: String {
        "\(String(describing: Kind.self))(name: \(name), path: \(path.string))"
    }
}
