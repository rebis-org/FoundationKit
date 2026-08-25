public import InfraKit
public import LogKit

public struct ErrLog<S: Sink<Record>>: Sendable {
    private let log: LogKit.Log<S>

    public init(identity: Identity, sink: S) {
        log = LogKit.Log(identity: identity, sink: sink)
    }

    public func log(
        _ error: some Error,
        level: Level = .error,
        location: Location = Location(
            fileID: #fileID, filePath: #filePath, function: #function, line: #line,
        ),
    ) {
        let snapshot = ErrSnapshot(error: error)
        log.log(
            Payload { logger, type in
                logger.log(level: type, "\(snapshot.chainDescription, privacy: .public)")
            },
            level: level,
            location: location,
            metadata: ["signature": snapshot.signature],
            fields: [
                Field(key: "domain", value: snapshot.domain, privacy: .public),
                Field(key: "code", value: String(snapshot.code), privacy: .public),
                Field(key: "type", value: snapshot.typeName, privacy: .public),
            ],
        )
    }

    public var signposter: Signpost {
        log.signposter
    }

    public var logSource: LogSource {
        let identity = log.identity
        return LogSource { query in
            try await LogSource.osLogStore().entries(
                matching: Query(
                    identity: identity,
                    level: query.level,
                    startEpochSeconds: query.startEpochSeconds,
                    endEpochSeconds: query.endEpochSeconds,
                    maximumEntries: query.maximumEntries,
                ),
            )
        }
    }
}

public extension ErrLog where S == LogKit.OSLogSink {
    init(identity: Identity) {
        log = LogKit.Log<LogKit.OSLogSink>.osLog(identity: identity)
    }
}
