#if os(macOS)
    #if OpenSwiftUI
        public import OpenSwiftUI
    #else
        public import SwiftUI
    #endif
    public import AppKit
    import ErrKit
    import InfraKit
    import LogKit

    private let windowKitErrorLog = ErrLog<OSLogSink>(
        identity: Identity(subsystem: "dev.rebis.WindowKit", category: "ui"),
    )

    public extension View {
        func windowLevel(
            _ level: some WindowLevel = WindowLevelPreset.notificationCenterAtLockScreen,
            using elevation: some WindowElevation = SkyLightWindowElevation.shared,
        ) -> some View {
            modifier(WindowLeveling(level: level, elevation: elevation))
        }
    }

    struct WindowLeveling: ViewModifier {
        @State private var window: NSWindow?
        private let level: any WindowLevel
        private let elevation: any WindowElevation
        private let hasMoved = Locked(false)

        init(level: some WindowLevel, elevation: some WindowElevation) {
            self.level = level
            self.elevation = elevation
        }

        func body(content: Content) -> some View {
            #if OpenSwiftUI
                content
                    .background(alignment: .center) {
                        WindowDiscovery($window)
                    }
                    .onChange(of: window) { _, newWindow in
                        moveWindowIfNeeded(newWindow)
                    }
            #else
                content
                    .background(WindowDiscovery($window))
                    .onChange(of: window) { _ in
                        moveWindowIfNeeded(window)
                    }
            #endif
        }

        private func moveWindowIfNeeded(_ window: NSWindow?) {
            guard !hasMoved.withLock({ $0 }), let window else { return }
            hasMoved.withLock { $0 = true }

            do {
                try elevation.elevate(window, to: level)
            } catch {
                windowKitErrorLog.log(error)
            }
        }
    }
#endif
