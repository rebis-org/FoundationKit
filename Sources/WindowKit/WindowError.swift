#if os(macOS)
    public import Foundation

    public enum WindowError: Error, LocalizedError {
        case frameworkUnavailable
        case symbolMissing
        case spaceCreationFailed
        case spaceLevelConfigurationFailed
        case spaceVisibilityFailed
        case windowCreationFailed
        case elevationFailed

        public var errorDescription: String? {
            switch self {
            case .frameworkUnavailable:
                "The SkyLight framework is unavailable"

            case .symbolMissing:
                "A required SkyLight symbol is missing"

            case .spaceCreationFailed:
                "Failed to create a window space"

            case .spaceLevelConfigurationFailed:
                "Failed to configure the window space level"

            case .spaceVisibilityFailed:
                "Failed to make the window space visible"

            case .windowCreationFailed:
                "Failed to create the overlay window"

            case .elevationFailed:
                "Failed to elevate the window to the requested level"
            }
        }
    }
#endif
