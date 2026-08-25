public struct Predicate<A>: Sendable {
    private let test: @Sendable (A) -> Bool

    @preconcurrency
    public init(_ test: @escaping @Sendable (A) -> Bool) {
        self.test = test
    }

    public init<E: PredicateExpression>(_ expression: E) where E.A == A {
        test = { expression.evaluate($0) }
    }

    public func matches(_ value: A) -> Bool {
        test(value)
    }
}

public protocol PredicateExpression<A>: Sendable {
    associatedtype A
    func evaluate(_ value: A) -> Bool
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

    var optional: Predicate<A?> {
        Predicate<A?> { value in
            guard let value else { return false }
            return self.matches(value)
        }
    }

    func map<B>(_ transform: @escaping @Sendable (B) -> A) -> Predicate<B> {
        Predicate<B> { self.matches(transform($0)) }
    }
}

public extension Predicate where A: Sequence & Sendable, A.Element: Sendable {
    static func any(matching predicate: Predicate<A.Element>) -> Predicate<A> {
        Predicate { sequence in
            sequence.contains(where: predicate.matches)
        }
    }

    static func all(matching predicate: Predicate<A.Element>) -> Predicate<A> {
        Predicate { sequence in
            sequence.allSatisfy(predicate.matches)
        }
    }
}
