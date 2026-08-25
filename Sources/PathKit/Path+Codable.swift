import Foundation

public extension CodingUserInfoKey {
    static let relativePath: CodingUserInfoKey = {
        guard let key = CodingUserInfoKey(rawValue: "dev.rebis.Path.relative") else {
            fatalError("Cannot create the relative-path coding key")
        }
        return key
    }()
}

extension Path: Codable {
    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        if value.hasPrefix("/") {
            string = value
        } else if let root = decoder.userInfo[.relativePath] as? Path {
            string = (root / value).string
        } else if let root = decoder.userInfo[.relativePath] as? DynamicPath {
            string = (root / value).string
        } else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "Cannot decode a relative path without CodingUserInfoKey.relativePath.",
                ),
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let root = encoder.userInfo[.relativePath] as? Path {
            try container.encode(relative(to: root))
        } else if let root = encoder.userInfo[.relativePath] as? DynamicPath {
            try container.encode(relative(to: root))
        } else {
            try container.encode(string)
        }
    }
}
