public protocol Sink<Element>: Sendable {
    associatedtype Element: Sendable
    func consume(_ element: borrowing Element)
}

public struct ClosureSink<Element: Sendable>: Sink {
    private let closure: @Sendable (Element) -> Void

    @preconcurrency
    public init(_ closure: @escaping @Sendable (Element) -> Void) {
        self.closure = closure
    }

    public func consume(_ element: borrowing Element) {
        closure(element)
    }
}

public extension Sink {
    @preconcurrency
    func filter(_ predicate: @escaping @Sendable (Element) -> Bool) -> some Sink<Element> {
        FilterSink(sink: self, predicate: predicate)
    }

    @preconcurrency
    func map<T: Sendable>(_ transform: @escaping @Sendable (T) -> Element) -> some Sink<
        T,
    > {
        MapSink(sink: self, transform: transform)
    }

    @preconcurrency
    func contramap<T: Sendable>(_ transform: @escaping @Sendable (T) -> Element) -> some Sink<
        T,
    > {
        MapSink(sink: self, transform: transform)
    }
}

private struct FilterSink<Downstream: Sink>: Sink {
    typealias Element = Downstream.Element

    private let sink: Downstream
    private let predicate: @Sendable (Downstream.Element) -> Bool

    init(sink: Downstream, predicate: @escaping @Sendable (Downstream.Element) -> Bool) {
        self.sink = sink
        self.predicate = predicate
    }

    func consume(_ element: borrowing Element) {
        if predicate(element) {
            sink.consume(element)
        }
    }
}

private struct MapSink<Input: Sendable, Downstream: Sink>: Sink {
    typealias Element = Input

    private let sink: Downstream
    private let transform: @Sendable (Input) -> Downstream.Element

    init(sink: Downstream, transform: @escaping @Sendable (Input) -> Downstream.Element) {
        self.sink = sink
        self.transform = transform
    }

    func consume(_ element: borrowing Input) {
        sink.consume(transform(element))
    }
}
