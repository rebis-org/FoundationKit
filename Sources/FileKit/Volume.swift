public import Foundation
public import PathKit

public protocol Readable: Sendable {
    func data(at path: Path) throws -> Data
    func symlinkTarget(at path: Path) throws -> Path
}

public protocol Writable: Sendable {
    func write(_ data: Data, at path: Path) throws
    func createFile(at path: Path, contents: Data?) throws
    func createDirectory(at path: Path, createIntermediateDirectories: Bool) throws
    func symlink(_ target: Path, at path: Path) throws
}

public protocol Navigable: Sendable {
    func exists(at path: Path) -> Bool
    func type(at path: Path) -> EntryType?
    func children(of path: Path, includingHidden: Bool) throws -> [Path]
    func enumerator(at path: Path) -> FileManager.DirectoryEnumerator?
}

public protocol Attributable: Sendable {
    func attributes(at path: Path) -> [FileAttributeKey: Any]
    func setAttributes(_ attributes: [FileAttributeKey: Any], at path: Path) throws
}

public protocol Mutable: Sendable {
    func copy(from source: Path, to destination: Path) throws
    func move(from source: Path, to destination: Path) throws
    func delete(at path: Path) throws
}

public protocol Resolvable: Sendable {
    func resolve(at path: Path) throws -> Path
}

public protocol Volume: Readable, Writable, Navigable, Attributable, Mutable, Resolvable, Sendable {}

public extension Navigable {
    func enumerator(at _: Path) -> FileManager.DirectoryEnumerator? {
        nil
    }
}
