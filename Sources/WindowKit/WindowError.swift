#if os(macOS)
    public import Foundation
    import ErrKit

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
                failure("load SkyLight framework")

            case .symbolMissing:
                failure("find SkyLight symbol")

            case .spaceCreationFailed:
                failure("create window space")

            case .spaceLevelConfigurationFailed:
                failure("configure window space level")

            case .spaceVisibilityFailed:
                failure("show window space")

            case .windowCreationFailed:
                failure("create overlay window")

            case .elevationFailed:
                failure("elevate window to requested level")
            }
        }
    }
#endif
