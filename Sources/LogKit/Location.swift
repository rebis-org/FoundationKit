public struct Location: Sendable {
    public let fileID: String
    public let filePath: String
    public let function: String
    public let line: UInt32

    public init(fileID: String, filePath: String, function: String, line: UInt32) {
        self.fileID = fileID
        self.filePath = filePath
        self.function = function
        self.line = line
    }
}
