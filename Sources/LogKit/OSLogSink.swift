public import InfraKit
import Foundation
import os

public struct OSLogSink: Sink {
    private let cache = Locked([Identity: os.Logger]())

    public init() {}

    public func consume(_ record: borrowing Record) {
        let identity = record.identity
        let logger = cache.withLock { cache in
            cache[identity]
                ?? {
                    let created = os.Logger(subsystem: identity.subsystem, category: identity.category)
                    cache[identity] = created
                    return created
                }()
        }
        record.payload.emit(logger, record.level.osType)
    }
}
