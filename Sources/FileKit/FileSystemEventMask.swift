import Foundation

public struct FileSystemEventMask: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let write = Self(rawValue: 1 << 0)
    public static let extend = Self(rawValue: 1 << 1)
    public static let attrib = Self(rawValue: 1 << 2)
    public static let link = Self(rawValue: 1 << 3)
    public static let rename = Self(rawValue: 1 << 4)
    public static let revoke = Self(rawValue: 1 << 5)
    public static let delete = Self(rawValue: 1 << 6)

    public static let all: FileSystemEventMask = [
        .write, .extend, .attrib, .link, .rename, .revoke, .delete,
    ]

    var dispatchSourceMask: DispatchSource.FileSystemEvent {
        DispatchSource.FileSystemEvent(rawValue: rawValue)
    }
}
