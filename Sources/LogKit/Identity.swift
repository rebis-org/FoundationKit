public struct Identity: Sendable, Hashable {
    public let subsystem: String
    public let category: String

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem.normalized()
        self.category = category.normalized()
    }
}

private extension String {
    func normalized() -> String {
        let start = firstIndex { !$0.isWhitespace } ?? endIndex
        let end = lastIndex { !$0.isWhitespace }.map { index(after: $0) } ?? start
        let trimmed = String(self[start ..< end])
        precondition(
            !trimmed.isEmpty, "LogKit identifier component cannot be empty or contain only whitespace.",
        )
        return trimmed
    }
}
