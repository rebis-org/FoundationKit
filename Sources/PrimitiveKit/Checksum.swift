private let fnvOffset: UInt64 = 0xCBF2_9CE4_8422_2325
private let fnvPrime: UInt64 = 0x100_0000_01B3

public struct Checksum: Hasher {
    public init() {}

    public func hash(_ value: String) -> UInt64 {
        value.utf8.reduce(fnvOffset) { ($0 ^ UInt64($1)) &* fnvPrime }
    }
}
