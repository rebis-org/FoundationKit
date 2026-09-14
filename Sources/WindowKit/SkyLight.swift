#if os(macOS)
    import CoreFoundation
    import Foundation

    final class SkyLight: @unchecked Sendable {
        typealias ConnectionID = @convention(c) () -> Int32
        typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
        typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
        typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
        typealias AddWindowsAndRemoveFromSpaces = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

        let mainConnectionID: ConnectionID
        let spaceCreate: SpaceCreate
        let spaceSetAbsoluteLevel: SpaceSetAbsoluteLevel
        let showSpaces: ShowSpaces
        let addWindowsAndRemoveFromSpaces: AddWindowsAndRemoveFromSpaces

        @unsafe
        init() throws {
            let handle = unsafe dlopen(
                "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
                RTLD_NOW,
            )
            guard unsafe handle != nil else {
                throw WindowError.frameworkUnavailable
            }
            mainConnectionID = try unsafe load(handle, "SLSMainConnectionID")
            spaceCreate = try unsafe load(handle, "SLSSpaceCreate")
            spaceSetAbsoluteLevel = try unsafe load(handle, "SLSSpaceSetAbsoluteLevel")
            showSpaces = try unsafe load(handle, "SLSShowSpaces")
            addWindowsAndRemoveFromSpaces = try unsafe load(
                handle,
                "SLSSpaceAddWindowsAndRemoveFromSpaces",
            )
        }
    }

    @unsafe
    private func load<T>(_ handle: UnsafeMutableRawPointer?, _ name: UnsafePointer<CChar>) throws -> T {
        guard let symbol = unsafe dlsym(handle, name) else {
            throw WindowError.symbolMissing
        }
        return unsafe unsafeBitCast(symbol, to: T.self)
    }

    final class WindowSpace: @unchecked Sendable {
        let id: Int32

        @unsafe
        init(library: SkyLight, level: Int32) throws {
            let connection = library.mainConnectionID()
            id = library.spaceCreate(connection, 1, 0)
            guard id != 0 else {
                throw WindowError.spaceCreationFailed
            }
            try ensure(library.spaceSetAbsoluteLevel(connection, id, level), .spaceLevelConfigurationFailed)
            try ensure(library.showSpaces(connection, [id] as CFArray), .spaceVisibilityFailed)
        }
    }

    private func ensure(_ code: Int32, _ error: WindowError) throws {
        guard code == 0 else {
            throw error
        }
    }
#endif
