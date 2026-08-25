public import Foundation

public struct NDJSONLine: Encodable, Sendable {
    public let timestamp: String
    public let subsystem: String
    public let category: String
    public let level: String
    public let process: String
    public let pid: Int
    public let message: String

    public init(
        timestamp: String, subsystem: String, category: String, level: String, process: String,
        pid: Int, message: String,
    ) {
        self.timestamp = timestamp
        self.subsystem = subsystem
        self.category = category
        self.level = level
        self.process = process
        self.pid = pid
        self.message = message
    }

    public init(_ entry: Entry, formatter: ISO8601DateFormatter) {
        timestamp = formatter.string(from: Date(timeIntervalSince1970: entry.epochSeconds))
        subsystem = entry.identity.subsystem
        category = entry.identity.category
        level = entry.level?.name ?? "unknown"
        process = entry.process ?? ProcessInfo.processInfo.processName
        pid = entry.pid ?? Int(ProcessInfo.processInfo.processIdentifier)
        message = entry.message
    }
}
