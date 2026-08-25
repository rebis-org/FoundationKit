import Foundation

public protocol ErrChain: Error {
    var underlyingError: (any Error)? { get }
}

public extension ErrChain {
    var underlyingError: (any Error)? {
        nil
    }
}

public extension Error {
    var underlyingError: (any Error)? {
        (self as? any ErrChain)?.underlyingError
            ?? (self as NSError).userInfo[NSUnderlyingErrorKey] as? any Error
    }
}
