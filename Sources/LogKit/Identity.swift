public struct Identity: Sendable, Hashable {
    public let subsystem: String
    public let category: String

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem.normalized()
        self.category = category.normalized()
    }
}

private extension String {
    // OSLog entries can carry an empty subsystem or category, so an empty
    // trimmed component is valid and MUST NOT trap during log export.
    func normalized() -> String {
        let start = firstIndex { !$0.isWhitespace } ?? endIndex
        let end = lastIndex { !$0.isWhitespace }.map { index(after: $0) } ?? start
        return String(self[start ..< end])
    }
}
