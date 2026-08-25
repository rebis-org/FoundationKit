public struct Entry: Sendable {
    public let epochSeconds: Double
    public let identity: Identity
    public let level: Level?
    public let message: String
    public let process: String?
    public let pid: Int?

    public init(
        epochSeconds: Double,
        identity: Identity,
        level: Level? = nil,
        message: String,
        process: String? = nil,
        pid: Int? = nil,
    ) {
        self.epochSeconds = epochSeconds
        self.identity = identity
        self.level = level
        self.message = message
        self.process = process
        self.pid = pid
    }
}
