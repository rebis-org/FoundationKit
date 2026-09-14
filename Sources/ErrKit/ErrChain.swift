import Foundation

public protocol ErrChain: Error {
    var underlyingError: (any Error)? { get }
}

extension ErrChain {
    public var underlyingError: (any Error)? {
        nil
    }
}

extension Error {
    public var underlyingError: (any Error)? {
        (self as? any ErrChain)?.underlyingError
            ?? (self as NSError).userInfo[NSUnderlyingErrorKey] as? any Error
    }
}
