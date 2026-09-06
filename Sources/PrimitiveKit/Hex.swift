private let nibbles: [UInt8] = Array("0123456789abcdef".utf8)

public enum Hex: Sendable {
    public static func encode(_ bytes: some Sequence<UInt8>, truncatedTo prefixLength: Int? = nil) -> String {
        let clamped = prefixLength.map { max($0, 0) }
        let shown: [UInt8] = clamped.map { Array(bytes.prefix(($0 + 1) / 2)) } ?? Array(bytes)
        var seed: [UInt8] = []
        seed.reserveCapacity(shown.count * 2)
        let hex = String(
            decoding: shown.reduce(into: seed) {
                $0.append(nibbles[Int($1 >> 4)])
                $0.append(nibbles[Int($1 & 0x0F)])
            },
            as: UTF8.self,
        )
        return clamped.map { String(hex.prefix($0)) } ?? hex
    }

    public static func encode(_ value: UInt64, truncatedTo prefixLength: Int? = nil) -> String {
        encode((0 ..< 8).map { UInt8(truncatingIfNeeded: value >> (56 - $0 * 8)) }, truncatedTo: prefixLength)
    }
}
