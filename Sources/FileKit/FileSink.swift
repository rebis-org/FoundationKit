public import Foundation

/// FileHandle is Sendable on these platforms, so only the closed flag needs guarding.
public struct FileSink: ~Copyable, Sendable {
    private let handle: FileHandle
    private let closed = FileCloseGuard()

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
    }

    public func write(_ data: Data) throws {
        guard !closed.isClosed else {
            throw FileSystemError.writeFailed(path: "", underlying: FileHandleError.alreadyClosed)
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
        guard closed.claim() else { return }
        try handle.close()
    }

    deinit {
        if !closed.isClosed {
            try? handle.close()
        }
    }
}
