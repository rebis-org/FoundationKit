public struct Predicate<A>: Sendable {
    private let test: @Sendable (A) -> Bool

    @preconcurrency
    public init(_ test: @escaping @Sendable (A) -> Bool) {
        self.test = test
    }

    public func matches(_ value: A) -> Bool {
        test(value)
    }
}

public extension Predicate {
    static func && (lhs: Predicate, rhs: Predicate) -> Predicate {
        Predicate { lhs.matches($0) && rhs.matches($0) }
    }

    static func || (lhs: Predicate, rhs: Predicate) -> Predicate {
        Predicate { lhs.matches($0) || rhs.matches($0) }
    }

    static prefix func ! (rhs: Predicate) -> Predicate {
        Predicate { !rhs.matches($0) }
    }

    static var always: Predicate {
        Predicate { _ in true }
    }

    static var never: Predicate {
        Predicate { _ in false }
    }
}
