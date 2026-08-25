import Foundation
import OSLog

public enum Level: Sendable, Equatable {
    case trace, debug, info, notice, warning, error, fault

    public var name: String {
        switch self {
        case .trace: "trace"
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .warning: "warning"
        case .error: "error"
        case .fault: "fault"
        }
    }

    var osType: OSLogType {
        switch self {
        case .trace, .debug: .debug
        case .info: .info
        case .notice, .warning: .default
        case .error: .error
        case .fault: .fault
        }
    }

    var messageType: String {
        switch self {
        case .trace, .debug: "debug"
        case .info: "info"
        case .notice, .warning: "default"
        case .error: "error"
        case .fault: "fault"
        }
    }

    init?(osLogLevel: OSLogEntryLog.Level) {
        switch osLogLevel {
        case .debug: self = .debug
        case .info: self = .info
        case .notice: self = .notice
        case .error: self = .error
        case .fault: self = .fault
        default: return nil
        }
    }
}
