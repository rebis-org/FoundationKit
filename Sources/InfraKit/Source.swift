public protocol Source<Element>: Sendable {
    associatedtype Element: Sendable
    func next() -> Element?
}

public struct ClosureSource<Element: Sendable>: Source {
    private let closure: @Sendable () -> Element?

    @preconcurrency
    public init(_ closure: @escaping @Sendable () -> Element?) {
        self.closure = closure
    }

    public func next() -> Element? {
        closure()
    }
}

public extension Source {
    @preconcurrency
    func map<T: Sendable>(_ transform: @escaping @Sendable (Element) -> T) -> some Source<T> {
        MapSource(source: self, transform: transform)
    }

    @preconcurrency
    func filter(_ predicate: @escaping @Sendable (Element) -> Bool) -> some Source<Element> {
        FilterSource(source: self, predicate: predicate)
    }

    @preconcurrency
    func compactMap<T: Sendable>(_ transform: @escaping @Sendable (Element) -> T?)
        -> some Source<T>
    {
        CompactMapSource(source: self, transform: transform)
    }

    func take(_ count: Int) -> some Source<Element> {
        TakeSource(source: self, count: count)
    }

    func drop(_ count: Int) -> some Source<Element> {
        DropSource(source: self, count: count)
    }

    func concat(_ other: some Source<Element>) -> some Source<Element> {
        ConcatSource(first: self, second: other)
    }
}

private struct MapSource<Upstream: Source, Output: Sendable>: Source {
    typealias Element = Output

    private let source: Upstream
    private let transform: @Sendable (Upstream.Element) -> Output

    init(source: Upstream, transform: @escaping @Sendable (Upstream.Element) -> Output) {
        self.source = source
        self.transform = transform
    }

    func next() -> Output? {
        source.next().map(transform)
    }
}

private struct FilterSource<Upstream: Source>: Source {
    typealias Element = Upstream.Element

    private let source: Upstream
    private let predicate: @Sendable (Upstream.Element) -> Bool

    init(source: Upstream, predicate: @escaping @Sendable (Upstream.Element) -> Bool) {
        self.source = source
        self.predicate = predicate
    }

    func next() -> Upstream.Element? {
        while let element = source.next() {
            if predicate(element) {
                return element
            }
        }
        return nil
    }
}

private struct CompactMapSource<Upstream: Source, Output: Sendable>: Source {
    typealias Element = Output

    private let source: Upstream
    private let transform: @Sendable (Upstream.Element) -> Output?

    init(source: Upstream, transform: @escaping @Sendable (Upstream.Element) -> Output?) {
        self.source = source
        self.transform = transform
    }

    func next() -> Output? {
        while let element = source.next() {
            if let output = transform(element) {
                return output
            }
        }
        return nil
    }
}

private final class TakeSource<Upstream: Source>: Source {
    typealias Element = Upstream.Element

    private let source: Upstream
    private let remaining: Locked<Int>

    init(source: Upstream, count: Int) {
        self.source = source
        remaining = Locked(max(0, count))
    }

    func next() -> Upstream.Element? {
        remaining.withLock { remaining in
            guard remaining > 0 else { return nil }
            remaining -= 1
            return source.next()
        }
    }
}

private final class DropSource<Upstream: Source>: Source {
    typealias Element = Upstream.Element

    private let source: Upstream
    private let remaining: Locked<Int>

    init(source: Upstream, count: Int) {
        self.source = source
        remaining = Locked(max(0, count))
    }

    func next() -> Upstream.Element? {
        remaining.withLock { remaining in
            while remaining > 0 {
                remaining -= 1
                _ = source.next()
            }
            return source.next()
        }
    }
}

private final class ConcatSource<First: Source, Second: Source>: Source
    where First.Element == Second.Element
{
    typealias Element = First.Element

    private let first: First
    private let second: Second
    private let firstDone: Locked<Bool>

    init(first: First, second: Second) {
        self.first = first
        self.second = second
        firstDone = Locked(false)
    }

    func next() -> First.Element? {
        if !firstDone.withLock({ $0 }) {
            if let element = first.next() {
                return element
            }
            firstDone.withLock { $0 = true }
        }
        return second.next()
    }
}
