public import Foundation

public extension Node where Kind == FileKind {
    func read() throws -> Data {
        try volume.data(at: path)
    }

    func readAsString(encodedAs encoding: String.Encoding = .utf8) throws -> String {
        guard let string = try String(data: read(), encoding: encoding) else {
            throw FileSystemError.stringDecodingFailed(path: path.string)
        }
        return string
    }

    func readAsInt() throws -> Int {
        let string = try readAsString()
        guard let int = Int(string) else {
            throw FileSystemError.notAnInt(path: path.string, value: string)
        }
        return int
    }

    func write(_ data: Data) throws {
        try volume.write(data, at: path)
    }

    func write(_ string: String, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw FileSystemError.stringEncodingFailed(string)
        }
        try write(data)
    }

    func append(_ data: Data) throws {
        let sink = try FileSink(file: self, append: true)
        try sink.write(data)
        try sink.close()
    }

    func append(_ string: String, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw FileSystemError.stringEncodingFailed(string)
        }
        try append(data)
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    public extension Node where Kind == FileKind {
        func open() {
            NSWorkspace.shared.open(url)
        }
    }
#endif
