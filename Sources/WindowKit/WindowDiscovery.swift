#if os(macOS)
    #if OpenSwiftUI
        import OpenSwiftUI
    #else
        import SwiftUI
    #endif
    import AppKit

    struct WindowDiscovery: NSViewRepresentable {
        @Binding private var window: NSWindow?

        init(_ window: Binding<NSWindow?>) {
            _window = window
        }

        func makeNSView(context _: Context) -> NSWindowDiscoveryView {
            let view = NSWindowDiscoveryView()
            view.windowPublisher = $window
            return view
        }

        func updateNSView(_: NSWindowDiscoveryView, context _: Context) {}
    }

    final class NSWindowDiscoveryView: NSView {
        var windowPublisher: Binding<NSWindow?> = .constant(nil)

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            guard let newWindow else { return }
            windowPublisher.wrappedValue = newWindow
        }
    }
#endif
