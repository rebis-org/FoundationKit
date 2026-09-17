public import InfraKit
import Foundation
import OSLog

public struct Log<S: Sink<Record>>: Sendable {
    public let identity: Identity
    public let signposter: Signpost
    private let sink: S
    private let clock: ContinuousClock

    public init(identity: Identity, sink: S, clock: ContinuousClock = ContinuousClock()) {
        self.identity = identity
        self.sink = sink
        self.clock = clock
        signposter = OSLogSignposter.make(identity: identity)
    }

    public static func osLog(identity: Identity, clock: ContinuousClock = ContinuousClock()) -> Log<
        OSLogSink,
    > {
        Log<OSLogSink>(identity: identity, sink: OSLogSink(), clock: clock)
    }

    public static func osLog(
        subsystem: String, category: String, clock: ContinuousClock = ContinuousClock(),
    ) -> Log<OSLogSink> {
        Log<OSLogSink>.osLog(identity: Identity(subsystem: subsystem, category: category), clock: clock)
    }

    public func log(
        _ payload: Payload,
        level: Level = .notice,
        location: Location = Location(
            fileID: #fileID, filePath: #filePath, function: #function, line: #line,
        ),
        metadata: [String: String] = [:],
        fields: [Field] = [],
    ) {
        sink.consume(
            Record(
                identity: identity,
                payload: payload,
                level: level,
                location: location,
                metadata: metadata,
                fields: fields,
                instant: clock.now,
            ),
        )
    }

    public func log(
        level: Level,
        _ message: String,
        context: [String: String] = [:],
        fileID: String = #fileID,
        filePath: String = #filePath,
        function: String = #function,
        line: UInt32 = #line,
    ) {
        emit(
            level,
            message,
            context,
            Location(
                fileID: fileID,
                filePath: filePath,
                function: function,
                line: line,
            ),
        )
    }

    public func trace(
        _ message: String,
        context: [String: String] = [:],
        fileID: String = #fileID,
        filePath: String = #filePath,
        function: String = #function,
        line: UInt32 = #line,
    ) {
        emit(
            .trace,
            message,
            context,
            Location(
                fileID: fileID,
                filePath: filePath,
                function: function,
                line: line,
            ),
        )
    }

    public func debug(
        _ message: String,
        context: [String: String] = [:],
        fileID: String = #fileID,
        filePath: String = #filePath,
        function: String = #function,
        line: UInt32 = #line,
    ) {
        emit(
            .debug,
            message,
            context,
            Location(
                fileID: fileID,
                filePath: filePath,
                function: function,
                line: line,
            ),
        )
    }

    public func info(
        _ message: String,
        context: [String: String] = [:],
        fileID: String = #fileID,
        filePath: String = #filePath,
        function: String = #function,
        line: UInt32 = #line,
    ) {
        emit(
            .info,
            message,
            context,
            Location(
                fileID: fileID,
                filePath: filePath,
                function: function,
                line: line,
            ),
        )
    }

    public func notice(
        _ message: String,
        context: [String: String] = [:],
        fileID: String = #fileID,
        filePath: String = #filePath,
        function: String = #function,
        line: UInt32 = #line,
    ) {
        emit(
            .notice,
            message,
            context,
            Location(
                fileID: fileID,
                filePath: filePath,
                function: function,
                line: line,
            ),
        )
    }

    public func warning(
        _ message: String,
        context: [String: String] = [:],
        fileID: String = #fileID,
        filePath: String = #filePath,
        function: String = #function,
        line: UInt32 = #line,
    ) {
        emit(
            .warning,
            message,
            context,
            Location(
                fileID: fileID,
                filePath: filePath,
                function: function,
                line: line,
            ),
        )
    }

    public func error(
        _ message: String,
        context: [String: String] = [:],
        fileID: String = #fileID,
        filePath: String = #filePath,
        function: String = #function,
        line: UInt32 = #line,
    ) {
        emit(
            .error,
            message,
            context,
            Location(
                fileID: fileID,
                filePath: filePath,
                function: function,
                line: line,
            ),
        )
    }

    public func error(
        _ error: some Error,
        context: [String: String] = [:],
        fileID: String = #fileID,
        filePath: String = #filePath,
        function: String = #function,
        line: UInt32 = #line,
    ) {
        emit(
            .error,
            error.localizedDescription,
            context,
            Location(
                fileID: fileID,
                filePath: filePath,
                function: function,
                line: line,
            ),
        )
    }

    public func fault(
        _ message: String,
        context: [String: String] = [:],
        fileID: String = #fileID,
        filePath: String = #filePath,
        function: String = #function,
        line: UInt32 = #line,
    ) {
        emit(
            .fault,
            message,
            context,
            Location(
                fileID: fileID,
                filePath: filePath,
                function: function,
                line: line,
            ),
        )
    }

    private func emit(
        _ level: Level,
        _ message: String,
        _ context: [String: String],
        _ location: Location,
    ) {
        log(
            .osLog(message: message, tail: Tail(at: location, context: context).encoded()),
            level: level,
            location: location,
            metadata: context,
        )
    }
}
