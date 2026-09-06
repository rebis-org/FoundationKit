import CryptoKit

public import Foundation

public enum Digest: Sendable {
    public static func hex(_ value: String, truncatedTo prefixLength: Int? = nil) -> String {
        hex(Data(value.utf8), truncatedTo: prefixLength)
    }

    public static func hex(_ data: Data, truncatedTo prefixLength: Int? = nil) -> String {
        Hex.encode(CryptoKit.SHA256.hash(data: data), truncatedTo: prefixLength)
    }
}
