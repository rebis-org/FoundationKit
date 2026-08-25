public import Foundation
public import InfraKit

/// The closed flag is guarded by Locked; FileHandle is Sendable on these platforms.
public struct FileSink: ~Copyable, Sendable {
    private let handle: FileHandle
    private let closed: Locked<Bool>

    public init(file: File, append: Bool = false) throws {
        if !append {
            try file.volume.write(Data(), at: file.path)
        }
        do {
            handle = try FileHandle(forWritingTo: file.url)
        } catch {
            throw FileSystemError.writeFailed(path: file.path.string, underlying: error)
        }
        if append {
            handle.seekToEndOfFile()
        }
        closed = Locked(false)
    }

    public func write(_ data: Data) throws {
        guard !closed.withLock({ $0 }) else {
            throw FileSystemError.writeFailed(path: "", underlying: SinkError.alreadyClosed)
        }
        handle.write(data)
    }

    public func write(_ string: String, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw FileSystemError.stringEncodingFailed(string)
        }
        try write(data)
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

private enum SinkError: Error {
    case alreadyClosed
}
