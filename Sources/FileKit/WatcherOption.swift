public import Foundation
public import InfraKit

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

public enum Priority: Sendable {
    case userInteractive
    case userInitiated
    case utility
    case background
    case `default`

    var dispatchQoS: DispatchQoS {
        switch self {
        case .userInteractive: .userInteractive
        case .userInitiated: .userInitiated
        case .utility: .utility
        case .background: .background
        case .default: .default
        }
    }
}

public struct WatcherOption: Sendable {
    public var qos: Priority
    public var debounceInterval: TimeInterval
    public var eventMask: FileSystemEventMask
    public var predicate: InfraKit.Predicate<URL>
    public var scansChangedDirectoriesForFilteredEvents: Bool

    public init(
        qos: Priority = .utility,
        debounceInterval: TimeInterval = 0.5,
        eventMask: FileSystemEventMask = [.write, .extend, .delete, .rename],
        predicate: InfraKit.Predicate<URL> = .always,
        scansChangedDirectoriesForFilteredEvents: Bool = true,
    ) {
        self.qos = qos
        self.debounceInterval = debounceInterval
        self.eventMask = eventMask
        self.predicate = predicate
        self.scansChangedDirectoriesForFilteredEvents = scansChangedDirectoriesForFilteredEvents
    }

    var queue: DispatchQueue {
        .global(qos: qos.dispatchQoS.qosClass)
    }
}

public enum RecursiveWatchBackend: Equatable, Sendable {
    case automatic
    case dispatchSource
    case fsevents
}

public struct RecursiveWatchOptions: Sendable {
    public var maxDepth: Int?
    public var followSymlinks: Bool
    public var excludePatterns: [String]
    public var maxWatchedDirectories: Int
    public var backend: RecursiveWatchBackend

    public init() {
        maxDepth = nil
        followSymlinks = false
        excludePatterns = []
        maxWatchedDirectories = 256
        backend = .dispatchSource
    }

    public init(
        maxDepth: Int? = nil,
        followSymlinks: Bool = false,
        excludePatterns: [String] = [],
        maxWatchedDirectories: Int = 256,
    ) {
        self.maxDepth = maxDepth
        self.followSymlinks = followSymlinks
        self.excludePatterns = excludePatterns
        self.maxWatchedDirectories = maxWatchedDirectories
        backend = .dispatchSource
    }

    public init(
        maxDepth: Int? = nil,
        followSymlinks: Bool = false,
        excludePatterns: [String] = [],
        maxWatchedDirectories: Int = 256,
        backend: RecursiveWatchBackend,
    ) {
        self.maxDepth = maxDepth
        self.followSymlinks = followSymlinks
        self.excludePatterns = excludePatterns
        self.maxWatchedDirectories = maxWatchedDirectories
        self.backend = backend
    }
}
