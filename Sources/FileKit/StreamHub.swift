import Foundation
import InfraKit

final class StreamHub<Element: Sendable>: Sendable {
    private let continuations = Locked([UUID: AsyncStream<Element>.Continuation]())

    var stream: AsyncStream<Element> {
        AsyncStream { continuation in
            let id = UUID()
            let continuations = self.continuations
            continuations.withLock { $0[id] = continuation }
            continuation.onTermination = { _ in
                continuations.withLock { _ = $0.removeValue(forKey: id) }
            }
        }
    }

    func yield(_ element: Element) {
        for continuation in continuations.withLock({ Array($0.values) }) {
            continuation.yield(element)
        }
    }

    func finish() {
        for continuation in continuations.withLock({
            let values = Array($0.values)
            $0.removeAll()
            return values
        }) {
            continuation.finish()
        }
    }
}
