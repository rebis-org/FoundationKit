public struct Predicate<Value>: Sendable {
    private let test: @Sendable (Value) -> Bool

    @preconcurrency
    public init(_ test: @escaping @Sendable (Value) -> Bool) {
        self.test = test
    }

    public init<E: PredicateExpression>(_ expression: E) where E.Value == Value {
        test = { expression.evaluate($0) }
    }

    public func matches(_ value: Value) -> Bool {
        test(value)
    }
}

public protocol PredicateExpression<Value>: Sendable {
    associatedtype Value
    func evaluate(_ value: Value) -> Bool
}

extension Predicate {
    public static func && (lhs: Predicate, rhs: Predicate) -> Predicate {
        Predicate { lhs.matches($0) && rhs.matches($0) }
    }

    public static func || (lhs: Predicate, rhs: Predicate) -> Predicate {
        Predicate { lhs.matches($0) || rhs.matches($0) }
    }

    public static prefix func ! (rhs: Predicate) -> Predicate {
        Predicate { !rhs.matches($0) }
    }

    public static var always: Predicate {
        Predicate { _ in true }
    }

    public static var never: Predicate {
        Predicate { _ in false }
    }

    public var optional: Predicate<Value?> {
        Predicate<Value?> { value in
            guard let value else { return false }

            return self.matches(value)
        }
    }

    public func map<B>(_ transform: @escaping @Sendable (B) -> Value) -> Predicate<B> {
        Predicate<B> { self.matches(transform($0)) }
    }
}

extension Predicate where Value: Sequence & Sendable, Value.Element: Sendable {
    public static func any(matching predicate: Predicate<Value.Element>) -> Predicate<Value> {
        Predicate { sequence in
            sequence.contains(where: predicate.matches)
        }
    }

    public static func all(matching predicate: Predicate<Value.Element>) -> Predicate<Value> {
        Predicate { sequence in
            sequence.allSatisfy(predicate.matches)
        }
    }
}
