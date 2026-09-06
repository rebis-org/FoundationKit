import Foundation

public enum Priority: Sendable {
    case userInteractive
    case userInitiated
    case utility
    case background
    case `default`

    var dispatchQoS: DispatchQoS {
        switch self {
        case .userInteractive: .userInteractive
        case .userInitiated: .userInitiated
        case .utility: .utility
        case .background: .background
        case .default: .default
        }
    }
}
