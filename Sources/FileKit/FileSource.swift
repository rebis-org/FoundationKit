public import Foundation
import InfraKit

/// The closed flag is guarded by Locked; FileHandle is Sendable on these platforms.
public struct FileSource: ~Copyable, Sendable {
    private let handle: FileHandle
    private let closed: Locked<Bool>

    public init(file: File) throws {
        do {
            handle = try FileHandle(forReadingFrom: file.url)
        } catch {
            throw FileSystemError.readFailed(path: file.path.string, underlying: error)
        }
        closed = Locked(false)
    }

    public func read() throws -> Data {
        guard !closed.withLock({ $0 }) else {
            throw FileSystemError.readFailed(path: "", underlying: SourceError.alreadyClosed)
        }
        return handle.readDataToEndOfFile()
    }

    public func readAsString(encoding: String.Encoding = .utf8) throws -> String {
        guard let string = try String(data: read(), encoding: encoding) else {
            throw FileSystemError.stringDecodingFailed(path: "")
        }
        return string
    }

    public consuming func close() throws {
        let wasClosed = closed.withLock { closed in
            let previous = closed
            closed = true
            return previous
        }
        guard !wasClosed else { return }
        try handle.close()
    }

    deinit {
        if !closed.withLock({ $0 }) {
            try? handle.close()
        }
    }
}

private enum SourceError: Error {
    case alreadyClosed
}
