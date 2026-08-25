public struct Record: Sendable {
    public let identity: Identity
    public let payload: Payload
    public let level: Level
    public let location: Location
    public let metadata: [String: String]
    public let fields: [Field]
    public let instant: ContinuousClock.Instant
}
