public struct Query: Sendable {
    public let identity: Identity?
    public let level: Level?
    public let startEpochSeconds: Double?
    public let endEpochSeconds: Double?
    public let maximumEntries: Int

    public init(
        identity: Identity? = nil,
        level: Level? = nil,
        startEpochSeconds: Double? = nil,
        endEpochSeconds: Double? = nil,
        maximumEntries: Int = 1_000,
    ) {
        self.identity = identity
        self.level = level
        self.startEpochSeconds = startEpochSeconds
        self.endEpochSeconds = endEpochSeconds
        self.maximumEntries = maximumEntries
    }
}
