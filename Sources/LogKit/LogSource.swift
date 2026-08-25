import Foundation
import OSLog

public struct LogSource: Sendable {
    public typealias Entries = @Sendable (Query) async throws -> [Entry]
    private let entries: Entries

    public init(entries: @escaping Entries) {
        self.entries = entries
    }

    public func entries(matching query: Query) async throws -> [Entry] {
        try await entries(query)
    }
}

public extension LogSource {
    static func osLogStore() -> LogSource {
        LogSource { query in
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position =
                query.startEpochSeconds.map { store.position(date: Date(timeIntervalSince1970: $0)) }
                    ?? store.position(timeIntervalSinceLatestBoot: 0)

            var predicates: [NSPredicate] = []
            if let identity = query.identity {
                predicates.append(NSPredicate(format: "subsystem == %@", identity.subsystem))
                predicates.append(NSPredicate(format: "category == %@", identity.category))
            }
            if let level = query.level {
                predicates.append(NSPredicate(format: "messageType == %@", level.messageType))
            }
            let predicate =
                predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

            var result: [Entry] = []
            result.reserveCapacity(min(query.maximumEntries, 1_024))

            for entry in try store.getEntries(at: position, matching: predicate) {
                try Task.checkCancellation()
                guard result.count < query.maximumEntries else { break }
                guard let log = entry as? OSLogEntryLog else { continue }
                if let end = query.endEpochSeconds, log.date.timeIntervalSince1970 > end {
                    break
                }
                result.append(
                    Entry(
                        epochSeconds: log.date.timeIntervalSince1970,
                        identity: Identity(subsystem: log.subsystem, category: log.category),
                        level: Level(osLogLevel: log.level),
                        message: log.composedMessage,
                        process: log.process,
                        pid: Int(log.processIdentifier),
                    ),
                )
            }
            return result
        }
    }
}
