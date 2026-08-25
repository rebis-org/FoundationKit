#if os(macOS)
    import CoreFoundation
    import Foundation

    final class WindowSpace: @unchecked Sendable {
        let id: Int32
        let level: any WindowLevel

        @unsafe
        init(library: SkyLight, level: any WindowLevel) throws {
            self.level = level

            let connection = library.mainConnectionID()
            id = library.spaceCreate(connection, 1, 0)
            guard id != 0 else {
                throw WindowError.spaceCreationFailed
            }

            let levelResult = library.spaceSetAbsoluteLevel(connection, id, level.rawValue)
            guard levelResult == 0 else {
                throw WindowError.spaceLevelConfigurationFailed
            }

            let showResult = library.showSpaces(connection, [id] as CFArray)
            guard showResult == 0 else {
                throw WindowError.spaceVisibilityFailed
            }
        }
    }
#endif
