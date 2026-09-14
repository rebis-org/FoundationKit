public protocol Hasher: Sendable {
    func hash(_ value: String) -> UInt64
}
