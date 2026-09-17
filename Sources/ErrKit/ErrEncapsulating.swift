public protocol ErrEncapsulating: Error {
    init(encapsulating error: some Error)
}

extension ErrEncapsulating {
    public static func encapsulate<Result>(_ operation: () throws -> Result) throws(Self) -> Result {
        do {
            return try operation()
        } catch {
            throw translated(error)
        }
    }

    @preconcurrency
    public static func encapsulate<Result>(_ operation: @Sendable () async throws -> Result)
        async throws(Self) -> Result {
        do {
            return try await operation()
        } catch {
            throw translated(error)
        }
    }

    private static func translated(_ error: some Error) -> Self {
        (error as? Self) ?? Self(encapsulating: error)
    }
}
