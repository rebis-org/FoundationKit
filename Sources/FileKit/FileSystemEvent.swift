public import Foundation

public struct FileSystemEvent: Sendable, Identifiable {
    public enum ItemKind: Equatable, Sendable {
        case file
        case directory
        case symbolicLink
        case unknown
    }

    public enum Change: Equatable, Sendable {
        case created
        case modified
        case deleted
        case renamed
        case unknown
    }

    public let url: URL
    public let change: Change
    public let itemKind: ItemKind
    public let timestamp: Date
    public let requiresRescan: Bool
    public let rawFlags: UInt32
    public let eventID: UInt64?

    public var id: UInt64? {
        eventID
    }

    public init(
        url: URL,
        change: Change,
        itemKind: ItemKind = .unknown,
        timestamp: Date = Date(),
        requiresRescan: Bool = false,
        rawFlags: UInt32 = 0,
        eventID: UInt64? = nil,
    ) {
        self.url = url
        self.change = change
        self.itemKind = itemKind
        self.timestamp = timestamp
        self.requiresRescan = requiresRescan
        self.rawFlags = rawFlags
        self.eventID = eventID
    }
}
