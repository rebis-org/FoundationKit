public protocol Hasher: Sendable {
    func hash(_ value: String) -> UInt64
}

public struct FNV1a: Hasher {
    private let offset: UInt64 = 0xCBF2_9CE4_8422_2325
    private let prime: UInt64 = 0x100_0000_01B3

    public init() {}

    public func hash(_ value: String) -> UInt64 {
        value.utf8.reduce(offset) { hash, byte in
            (hash ^ UInt64(byte)) &* prime
        }
    }
}
