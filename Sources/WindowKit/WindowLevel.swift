#if os(macOS)
    public protocol WindowLevel: Sendable {
        var rawValue: Int32 { get }
    }

    public enum WindowLevelPreset: Int32, WindowLevel {
        case `default` = 0
        case setupAssistant = 100
        case securityAgent = 200
        case screenLock = 300
        case notificationCenterAtLockScreen = 400
        case bootProgress = 500
        case voiceOver = 600
    }
#endif
