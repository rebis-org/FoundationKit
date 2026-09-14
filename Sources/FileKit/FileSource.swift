public import Foundation

/// FileHandle is Sendable on these platforms, so only the closed flag needs guarding.
public struct FileSource: ~Copyable, Sendable {
    private let handle: FileHandle
    private let closed = FileCloseGuard()

    public init(file: File) throws {
        do {
            handle = try FileHandle(forReadingFrom: file.url)
        } catch {
            throw FileSystemError.readFailed(path: file.path.string, underlying: error)
        }
    }

    public func read() throws -> Data {
        guard !closed.isClosed else {
            throw FileSystemError.readFailed(path: "", underlying: FileHandleError.alreadyClosed)
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
        guard closed.claim() else { return }
        try handle.close()
    }

    deinit {
        if !closed.isClosed {
            try? handle.close()
        }
    }
}
