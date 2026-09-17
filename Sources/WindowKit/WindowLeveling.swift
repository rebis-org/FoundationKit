#if os(macOS)
    #if OpenSwiftUI
        public import OpenSwiftUI
    #else
        public import SwiftUI
    #endif
    public import AppKit
    import ErrKit
    import LogKit

    private let windowKitErrorLog = ErrLog<OSLogSink>(
        identity: Identity(subsystem: "dev.rebis.WindowKit", category: "ui"),
    )

    extension View {
        public func windowLevel(
            _ level: some WindowLevel = WindowLevelPreset.notificationCenterAtLockScreen,
            using elevation: some WindowElevation = SkyLightWindowElevation.shared,
        ) -> some View {
            modifier(WindowLeveling(level: level, elevation: elevation))
        }
    }

    struct WindowLeveling<L: WindowLevel, E: WindowElevation>: ViewModifier {
        @State private var window: NSWindow?
        @State private var moved = false
        private let level: L
        private let elevation: E

        init(level: L, elevation: E) {
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
            guard !moved, let window else { return }

            moved = true

            do {
                try elevation.elevate(window, to: level)
            } catch {
                windowKitErrorLog.log(error)
            }
        }
    }

    private struct WindowDiscovery: NSViewRepresentable {
        @Binding var window: NSWindow?

        init(_ window: Binding<NSWindow?>) {
            _window = window
        }

        func makeNSView(context _: Context) -> Finder {
            let view = Finder()
            view.binding = $window
            return view
        }

        func updateNSView(_: Finder, context _: Context) {}

        final class Finder: NSView {
            var binding: Binding<NSWindow?> = .constant(nil)

            override func viewWillMove(toWindow newWindow: NSWindow?) {
                guard let newWindow else { return }

                binding.wrappedValue = newWindow
            }
        }
    }
#endif
