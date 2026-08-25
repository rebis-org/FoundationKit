#if os(macOS)
    import CoreFoundation
    import Foundation

    /// SkyLight isolates the private SkyLight C API loading and symbol resolution.
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

            guard
                let connectionIDSymbol = unsafe dlsym(handle, "SLSMainConnectionID"),
                let spaceCreateSymbol = unsafe dlsym(handle, "SLSSpaceCreate"),
                let spaceSetAbsoluteLevelSymbol = unsafe dlsym(handle, "SLSSpaceSetAbsoluteLevel"),
                let showSpacesSymbol = unsafe dlsym(handle, "SLSShowSpaces"),
                let addWindowsAndRemoveFromSpacesSymbol = unsafe dlsym(handle, "SLSSpaceAddWindowsAndRemoveFromSpaces")
            else {
                throw WindowError.symbolMissing
            }

            mainConnectionID = unsafe unsafeBitCast(connectionIDSymbol, to: ConnectionID.self)
            spaceCreate = unsafe unsafeBitCast(spaceCreateSymbol, to: SpaceCreate.self)
            spaceSetAbsoluteLevel = unsafe unsafeBitCast(spaceSetAbsoluteLevelSymbol, to: SpaceSetAbsoluteLevel.self)
            showSpaces = unsafe unsafeBitCast(showSpacesSymbol, to: ShowSpaces.self)
            addWindowsAndRemoveFromSpaces = unsafe unsafeBitCast(
                addWindowsAndRemoveFromSpacesSymbol,
                to: AddWindowsAndRemoveFromSpaces.self,
            )
        }
    }
#endif
