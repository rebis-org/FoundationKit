#if os(macOS)
    public import AppKit
    import ErrKit
    import Foundation
    import InfraKit
    import LogKit
    #if OpenSwiftUI
        public import OpenSwiftUI
    #else
        public import SwiftUI
    #endif

    @preconcurrency
    public protocol WindowElevation: Sendable {
        @MainActor
        func elevate(_ window: NSWindow, to level: any WindowLevel) throws

        @MainActor
        func present(_ view: AnyView, on screen: NSScreen, at level: any WindowLevel) throws -> NSWindowController
    }

    /// NSWindow and NSWindowController are not Sendable, so this class is unchecked;
    /// all mutation happens on the main actor and the SkyLight state is immutable.
    public final class SkyLightWindowElevation: WindowElevation, @unchecked Sendable {
        public static let shared: SkyLightWindowElevation = {
            do {
                return try unsafe SkyLightWindowElevation()
            } catch {
                let log = ErrLog<OSLogSink>(identity: Identity(subsystem: "dev.rebis.WindowKit", category: "window"))
                log.log(error)
                fatalError("SkyLight is unavailable: \(error)")
            }
        }()

        private let connection: SkyLight
        private let spaces: Locked<[Int32: WindowSpace]>

        @unsafe
        public init() throws {
            connection = try unsafe SkyLight()
            spaces = Locked([:])
        }

        @preconcurrency
        @MainActor
        public func elevate(_ window: NSWindow, to level: any WindowLevel) throws {
            let space = try space(for: level)
            let result = connection.addWindowsAndRemoveFromSpaces(
                connection.mainConnectionID(),
                space.id,
                [window.windowNumber] as CFArray,
                7,
            )
            guard result == 0 else {
                throw WindowError.elevationFailed
            }
        }

        @preconcurrency
        @MainActor
        public func present(_ view: AnyView, on screen: NSScreen, at level: any WindowLevel) throws -> NSWindowController {
            let hosting = OverlayWindowHosting(screen: screen)
            guard let window = hosting.window else {
                throw WindowError.windowCreationFailed
            }
            window.contentViewController = NSHostingController(rootView: view)
            window.setFrame(screen.frame, display: true)
            try elevate(window, to: level)
            window.makeKeyAndOrderFront(nil)
            return hosting
        }

        @MainActor
        private func space(for level: any WindowLevel) throws -> WindowSpace {
            let rawValue = level.rawValue
            if let cached = spaces.withLock({ $0[rawValue] }) {
                return cached
            }
            let space = try unsafe WindowSpace(library: connection, level: level)
            spaces.withLock { $0[rawValue] = space }
            return space
        }
    }
#endif
