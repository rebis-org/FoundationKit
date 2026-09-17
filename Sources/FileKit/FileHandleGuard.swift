import InfraKit

struct FileCloseGuard: Sendable {
    private let closed = Locked(false)

    var isClosed: Bool {
        closed.withLock { $0 }
    }

    func claim() -> Bool {
        closed.withLock { closed in
            let previous = closed
            closed = true
            return !previous
        }
    }
}

enum FileHandleError: Error {
    case alreadyClosed
}
