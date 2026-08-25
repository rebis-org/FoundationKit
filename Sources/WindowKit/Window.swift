#if os(macOS)
    import AppKit

    final class OverlayWindow: NSWindow {
        override init(
            contentRect: NSRect,
            styleMask: NSWindow.StyleMask,
            backing: NSWindow.BackingStoreType,
            defer flag: Bool,
        ) {
            super.init(
                contentRect: contentRect,
                styleMask: styleMask,
                backing: backing,
                defer: flag,
            )

            isOpaque = false
            alphaValue = 1
            titleVisibility = .hidden
            titlebarAppearsTransparent = true
            backgroundColor = .clear
            isMovable = false
            collectionBehavior = [
                .fullScreenAuxiliary,
                .stationary,
                .canJoinAllSpaces,
                .ignoresCycle,
            ]
            hasShadow = false
            canBecomeVisibleWithoutLogin = true
            level = .init(rawValue: .init(Int32.max - 2))
        }

        override var canBecomeKey: Bool {
            true
        }

        override var canBecomeMain: Bool {
            true
        }
    }

    @MainActor
    final class OverlayWindowHosting: NSWindowController {
        @MainActor
        init(screen: NSScreen) {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false,
                screen: screen,
            )
            super.init(window: window)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            // Storyboard/XIB loading is not used by WindowKit.
            nil
        }
    }
#endif
