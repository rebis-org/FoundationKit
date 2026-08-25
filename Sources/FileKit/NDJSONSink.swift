public import Foundation
public import LogKit
import PathKit

public struct NDJSONSink: ~Copyable {
    private var sink: FileSink
    private let encoder = JSONEncoder()
    private let formatter = ISO8601DateFormatter()

    public init(file: File) throws {
        sink = try FileSink(file: file)
        encoder.outputFormatting = [.withoutEscapingSlashes]
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    public init(url: URL) throws {
        let file = try File(path: Path(url: url) ?? Path(string: url.path), volume: FoundationVolume())
        try self.init(file: file)
    }

    public func write(_ line: NDJSONLine) throws {
        var data = try encoder.encode(line)
        data.append(contentsOf: [UInt8(ascii: "\n")])
        try sink.write(data)
    }

    public func write(from source: LogSource, since date: Date) async throws {
        let entries = try await source.entries(
            matching: Query(
                startEpochSeconds: date.timeIntervalSince1970,
                maximumEntries: .max,
            ),
        )
        for entry in entries {
            try Task.checkCancellation()
            try write(NDJSONLine(entry, formatter: formatter))
        }
    }

    public func write(since date: Date) async throws {
        try await write(from: .osLogStore(), since: date)
    }

    public consuming func close() throws {
        try sink.close()
    }
}
