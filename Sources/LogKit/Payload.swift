public import os
import Foundation

public struct Payload: Sendable {
    public typealias Emit = @Sendable (os.Logger, OSLogType) -> Void
    public let emit: Emit

    public init(emit: @escaping Emit) {
        self.emit = emit
    }

    public static func osLog(message: String, tail: String = "") -> Self {
        Self { logger, type in
            logger.log(level: type, "\(message, privacy: .public)\(tail, privacy: .public)")
        }
    }
}
