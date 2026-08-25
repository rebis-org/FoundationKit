public struct Field: Sendable, Equatable {
    public let key: String
    public let value: String
    public let privacy: Privacy

    public init(key: String, value: String, privacy: Privacy = .public) {
        self.key = key
        self.value = value
        self.privacy = privacy
    }
}
