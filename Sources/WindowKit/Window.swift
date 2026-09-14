#if os(macOS)
    import AppKit

    extension NSWindow {
        func applyOverlayStyle() {
            isOpaque = false
            backgroundColor = .clear
            isMovable = false
            hasShadow = false
            collectionBehavior = [
                .fullScreenAuxiliary,
                .stationary,
                .canJoinAllSpaces,
                .ignoresCycle,
            ]
        }
    }

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

            applyOverlayStyle()
            alphaValue = 1
            titleVisibility = .hidden
            titlebarAppearsTransparent = true
            canBecomeVisibleWithoutLogin = true
            level = .init(rawValue: .init(Int32.max - 2))
        }

        override var canBecomeKey: Bool {
            true
        }

        override var canBecomeMain: Bool {
            true
        }

        static func controller(screen: NSScreen) -> NSWindowController {
            NSWindowController(
                window: OverlayWindow(
                    contentRect: screen.frame,
                    styleMask: [.borderless, .fullSizeContentView],
                    backing: .buffered,
                    defer: false,
                    screen: screen,
                )
            )
        }
    }

    final class DynamicNotchPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }
#endif
