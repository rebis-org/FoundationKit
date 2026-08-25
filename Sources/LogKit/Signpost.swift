import Foundation
import os

public struct Signpost: Sendable {
    public typealias BeginInterval = @Sendable (StaticString, SignpostID?) -> SignpostInterval
    public typealias EmitEvent = @Sendable (StaticString, SignpostID?) -> Void

    private let begin: BeginInterval
    private let emit: EmitEvent

    public init(beginInterval: @escaping BeginInterval, emitEvent: @escaping EmitEvent) {
        begin = beginInterval
        emit = emitEvent
    }

    public func beginInterval(named name: StaticString, id: SignpostID? = nil) -> SignpostInterval {
        begin(name, id)
    }

    public func emitEvent(named name: StaticString, id: SignpostID? = nil) {
        emit(name, id)
    }

    public static let disabled: Signpost = .init(
        beginInterval: { _, _ in SignpostInterval {} },
        emitEvent: { _, _ in },
    )
}

enum OSLogSignposter {
    static func make(identity: Identity) -> Signpost {
        let signposter = OSSignposter(subsystem: identity.subsystem, category: identity.category)
        return Signpost(
            beginInterval: { name, id in
                let state = signposter.beginInterval(name, id: makeID(id))
                return SignpostInterval { signposter.endInterval(name, state) }
            },
            emitEvent: { name, id in
                signposter.emitEvent(name, id: makeID(id))
            },
        )
    }

    private static func makeID(_ id: SignpostID?) -> OSSignpostID {
        id.map { OSSignpostID($0.rawValue) } ?? .exclusive
    }
}
