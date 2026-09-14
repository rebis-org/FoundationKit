import Foundation
import os

#if canImport(Synchronization)
    import Synchronization
#endif

public protocol Lock: Sendable {
    associatedtype Value: Sendable
    func withLock<R: Sendable>(_ body: @Sendable (inout Value) throws -> R) rethrows -> R
}

public struct Locked<Value: Sendable>: Lock {
    private let box: any GuardedBox<Value>

    public init(_ value: Value) {
        #if canImport(Synchronization)
            if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, macCatalyst 18, *) {
                box = MutexBox(value)
                return
            }
        #endif
        box = UnfairLockBox(value)
    }

    @preconcurrency
    public func withLock<R: Sendable>(_ body: @Sendable (inout Value) throws -> R) rethrows -> R {
        try box.withLock(body)
    }
}

private protocol GuardedBox<Value>: Sendable, AnyObject {
    associatedtype Value: Sendable
    func withLock<R: Sendable>(_ body: @Sendable (inout Value) throws -> R) rethrows -> R
}

#if canImport(Synchronization)
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, macCatalyst 18, *)
    private final class MutexBox<Value: Sendable>: GuardedBox {
        private let mutex: Synchronization.Mutex<Value>

        init(_ value: Value) {
            mutex = Synchronization.Mutex(value)
        }

        func withLock<R: Sendable>(_ body: @Sendable (inout Value) throws -> R) rethrows -> R {
            try mutex.withLock { state in
                try body(&state)
            }
        }
    }
#endif

private final class UnfairLockBox<Value: Sendable>: GuardedBox {
    private let lock: OSAllocatedUnfairLock<Value>

    init(_ value: Value) {
        lock = OSAllocatedUnfairLock(initialState: value)
    }

    func withLock<R: Sendable>(_ body: @Sendable (inout Value) throws -> R) rethrows -> R {
        try lock.withLock(body)
    }
}
