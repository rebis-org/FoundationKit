public struct Identity: Sendable, Hashable {
    public let subsystem: String
    public let category: String

    public init(subsystem: String, category: String) {
        self.subsystem = Self.normalized(subsystem)
        self.category = Self.normalized(category)
    }

    /// OSLog entries can carry an empty subsystem or category, so an empty
    /// trimmed component is valid and MUST NOT trap during log export.
    private static func normalized(_ value: String) -> String {
        let start = value.firstIndex { !$0.isWhitespace } ?? value.endIndex
        let end = value.lastIndex { !$0.isWhitespace }.map { value.index(after: $0) } ?? start
        return String(value[start ..< end])
    }
}
