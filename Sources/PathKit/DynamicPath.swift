@dynamicMemberLookup
public struct DynamicPath: Item, Sendable {
    public let string: String

    init(string: String) {
        assert(string.hasPrefix("/"))
        self.string = string
    }

    public init(_ path: some Item) {
        string = path.string
    }

    public subscript(dynamicMember component: String) -> Self {
        Self(string: Path.join(string, component.split(separator: "/")))
    }
}

extension DynamicPath: CustomStringConvertible {
    public var description: String {
        string
    }
}

extension DynamicPath: CustomDebugStringConvertible {
    public var debugDescription: String {
        "DynamicPath(\(string))"
    }
}
