public import Foundation
import PathKit

extension Node where Kind == FileKind {
    public func read() throws -> Data {
        try volume.data(at: path)
    }

    public func readAsString(encodedAs encoding: String.Encoding = .utf8) throws -> String {
        guard let string = try String(data: read(), encoding: encoding) else {
            throw FileSystemError.stringDecodingFailed(path: path.string)
        }

        return string
    }

    public func readAsInt() throws -> Int {
        let string = try readAsString()
        guard let int = Int(string) else {
            throw FileSystemError.notAnInt(path: path.string, value: string)
        }

        return int
    }

    public func write(_ data: Data) throws {
        try volume.write(data, at: path)
    }

    public func write(_ string: String, encoding: String.Encoding = .utf8) throws {
        try write(encoded(string, encoding: encoding))
    }

    public func append(_ data: Data) throws {
        let sink = try FileSink(file: self, append: true)
        try sink.write(data)
        try sink.close()
    }

    public func append(_ string: String, encoding: String.Encoding = .utf8) throws {
        try append(encoded(string, encoding: encoding))
    }

    private func encoded(_ string: String, encoding: String.Encoding) throws -> Data {
        guard let data = string.data(using: encoding) else {
            throw FileSystemError.stringEncodingFailed(string)
        }

        return data
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    extension Node where Kind == FileKind {
        public func open() {
            NSWorkspace.shared.open(url)
        }
    }
#endif
