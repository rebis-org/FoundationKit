#if os(macOS)
    public import AppKit
    #if OpenSwiftUI
        public import OpenSwiftUI
    #else
        public import SwiftUI
    #endif

    @MainActor
    public final class DynamicNotchWindowController: NSObject {
        private var panel: DynamicNotchPanel?
        private var contentView: DynamicNotchWindowContentView?
        private var hostingView: NSHostingView<AnyView>?
        private var hideGeneration = 0

        public private(set) var isVisible = false
        public private(set) var configuration: DynamicNotchConfiguration?
        public private(set) var placement: DynamicNotchPlacement?
        public private(set) var presentationMode: DynamicNotchPresentationMode?

        override public init() {
            super.init()
        }

        public func show(
            direction: DynamicNotchDirection = .top,
            width: CGFloat,
            height: CGFloat,
            cornerRadius: CGFloat? = nil,
            shoulderRadius: CGFloat? = nil,
            attachedEdgeRail: CGFloat? = nil,
            background: Color = .black,
            contentInsets: EdgeInsets = EdgeInsets(),
            screen: NSScreen? = nil,
            animated: Bool = true,
            at level: (any WindowLevel)? = nil,
            using elevation: (any WindowElevation)? = nil,
            @ContentBuilder content: @escaping () -> some View,
        ) throws {
            try show(
                placement: .edge(direction),
                width: width,
                height: height,
                cornerRadius: cornerRadius,
                shoulderRadius: shoulderRadius,
                attachedEdgeRail: attachedEdgeRail,
                background: background,
                contentInsets: contentInsets,
                screen: screen,
                animated: animated,
                at: level,
                using: elevation,
                content: content,
            )
        }

        public func show(
            placement: DynamicNotchPlacement,
            width: CGFloat,
            height: CGFloat,
            cornerRadius: CGFloat? = nil,
            shoulderRadius: CGFloat? = nil,
            attachedEdgeRail: CGFloat? = nil,
            background: Color = .black,
            contentInsets: EdgeInsets = EdgeInsets(),
            screen: NSScreen? = nil,
            animated: Bool = true,
            at level: (any WindowLevel)? = nil,
            using elevation: (any WindowElevation)? = nil,
            @ContentBuilder content: @escaping () -> some View,
        ) throws {
            let targetScreen = resolvedScreen(screen)
            let safeAreaInsets = targetScreen?.safeAreaInsets ?? NSEdgeInsets()
            let nextConfiguration = DynamicNotchConfiguration(
                direction: placement.direction,
                width: width,
                height: height,
                cornerRadius: cornerRadius,
                shoulderRadius: shoulderRadius,
                attachedEdgeRail: DynamicNotchSafeAreaResolver.attachedEdgeRail(
                    for: placement.direction,
                    override: attachedEdgeRail,
                    safeAreaInsets: safeAreaInsets,
                ),
            )
            let rootView = DynamicNotch(
                direction: nextConfiguration.direction,
                width: nextConfiguration.width,
                height: nextConfiguration.height,
                cornerRadius: nextConfiguration.cornerRadius,
                shoulderRadius: nextConfiguration.shoulderRadius,
                attachedEdgeRail: nextConfiguration.attachedEdgeRail,
                background: background,
                contentInsets: contentInsets,
                content: content,
            )

            try present(
                Presentation(
                    rootView: AnyView(rootView),
                    configuration: nextConfiguration,
                    placement: placement,
                    screen: targetScreen,
                    animated: animated,
                    mode: .expanded,
                    level: level,
                    elevation: elevation,
                ),
            )
        }

        public func showCompact(
            width: CGFloat,
            height: CGFloat? = nil,
            centerGap: CGFloat? = nil,
            cornerRadius: CGFloat? = nil,
            shoulderRadius: CGFloat? = nil,
            background: Color = .black,
            contentInsets: EdgeInsets = EdgeInsets(),
            screen: NSScreen? = nil,
            animated: Bool = true,
            at level: (any WindowLevel)? = nil,
            using elevation: (any WindowElevation)? = nil,
            @ContentBuilder leading: @escaping () -> some View,
            @ContentBuilder trailing: @escaping () -> some View,
        ) throws {
            let targetScreen = resolvedScreen(screen)
            let safeAreaInsets = targetScreen?.safeAreaInsets ?? NSEdgeInsets()
            let nextConfiguration = DynamicNotchConfiguration(
                direction: .top,
                width: width,
                height: DynamicNotchSafeAreaResolver.compactHeight(
                    override: height,
                    statusBarThickness: NSStatusBar.system.thickness,
                    safeAreaInsets: safeAreaInsets,
                ),
                cornerRadius: cornerRadius,
                shoulderRadius: shoulderRadius,
                attachedEdgeRail: 0,
            )
            let rootView = DynamicNotchCompact(
                direction: .top,
                width: nextConfiguration.width,
                height: nextConfiguration.height,
                centerGap: DynamicNotchSafeAreaResolver.compactCenterGap(
                    override: centerGap,
                    auxiliaryTopLeftArea: targetScreen?.auxiliaryTopLeftArea,
                    auxiliaryTopRightArea: targetScreen?.auxiliaryTopRightArea,
                ),
                cornerRadius: nextConfiguration.cornerRadius,
                shoulderRadius: nextConfiguration.shoulderRadius,
                background: background,
                contentInsets: contentInsets,
                leading: leading,
                trailing: trailing,
            )

            try present(
                Presentation(
                    rootView: AnyView(rootView),
                    configuration: nextConfiguration,
                    placement: .edge(.top),
                    screen: targetScreen,
                    animated: animated,
                    mode: .compact,
                    level: level,
                    elevation: elevation,
                ),
            )
        }

        private struct Presentation {
            let rootView: AnyView
            let configuration: DynamicNotchConfiguration
            let placement: DynamicNotchPlacement
            let screen: NSScreen?
            let animated: Bool
            let mode: DynamicNotchPresentationMode
            let level: (any WindowLevel)?
            let elevation: (any WindowElevation)?
        }

        private func present(_ presentation: Presentation) throws {
            configuration = presentation.configuration
            placement = presentation.placement
            presentationMode = presentation.mode
            hideGeneration &+= 1

            let panel = makePanelIfNeeded()

            let surface: DynamicNotchWindowContentView
            if let contentView {
                contentView.updateShape(presentation.configuration)
                surface = contentView
            } else {
                surface = DynamicNotchWindowContentView(shape: presentation.configuration.shape)
                panel.contentView = surface
                contentView = surface
            }

            if let hostingView {
                hostingView.rootView = presentation.rootView
            } else {
                let newHostingView = NSHostingView(rootView: presentation.rootView)
                newHostingView.sizingOptions = []
                newHostingView.autoresizingMask = []
                newHostingView.wantsLayer = true
                newHostingView.layer?.backgroundColor = NSColor.clear.cgColor
                surface.installHostingView(newHostingView)
                hostingView = newHostingView
            }

            let targetFrame = DynamicNotchWindowGeometry.frame(
                for: presentation.configuration,
                placement: presentation.placement,
                in: presentation.screen?.frame ?? NSRect(x: 0, y: 0, width: 1_440, height: 900),
            )
            setFrame(targetFrame, on: panel, animated: presentation.animated && isVisible)
            if let level = presentation.level, let elevation = presentation.elevation {
                try elevation.elevate(panel, to: level)
            }
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            isVisible = true
        }

        private func resolvedScreen(_ screen: NSScreen?) -> NSScreen? {
            screen ?? NSScreen.main ?? panel?.screen ?? NSScreen.screens.first
        }

        public func hide(animated: Bool = true) {
            guard let panel else {
                isVisible = false
                return
            }

            hideGeneration &+= 1
            let generation = hideGeneration

            guard animated, panel.isVisible else {
                panel.orderOut(nil)
                panel.alphaValue = 1
                isVisible = false
                return
            }

            animate(panel, duration: 0.18, timing: .easeIn) {
                $0.alphaValue = 0
            } completionHandler: { [weak self, weak panel] in
                Task { @MainActor [weak self, weak panel] in
                    guard let self, let panel, hideGeneration == generation else { return }

                    panel.orderOut(nil)
                    panel.alphaValue = 1
                    isVisible = false
                }
            }
        }

        private func makePanelIfNeeded() -> DynamicNotchPanel {
            if let panel { return panel }

            let panel = DynamicNotchPanel(
                contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
            )
            panel.applyOverlayStyle()
            panel.level = .statusBar
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            self.panel = panel
            return panel
        }

        private func setFrame(_ targetFrame: NSRect, on panel: NSPanel, animated: Bool) {
            guard animated, panel.isVisible else {
                panel.setFrame(targetFrame, display: true)
                return
            }

            animate(panel, duration: 0.24, timing: .easeInEaseOut) {
                $0.setFrame(targetFrame, display: true)
            }
        }

        private func animate(
            _ panel: NSPanel,
            duration: TimeInterval,
            timing: CAMediaTimingFunctionName,
            apply: (NSPanel) -> Void,
            completionHandler: (@Sendable () -> Void)? = nil,
        ) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: timing)
                apply(panel.animator())
            } completionHandler: {
                completionHandler?()
            }
        }
    }

    private final class DynamicNotchWindowContentView: NSView {
        private var shape: DynamicNotchShape
        private var shapePath: CGPath?
        private var hostingClipView: DynamicNotchHostingClipView?

        init(shape: DynamicNotchShape) {
            self.shape = shape
            super.init(frame: .zero)
            autoresizingMask = [.width, .height]
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override var isFlipped: Bool { true }

        func updateShape(_ configuration: DynamicNotchConfiguration) {
            shape = configuration.shape
            updateShapePath()
            needsLayout = true
        }

        func installHostingView(_ view: NSView) {
            let clipView = DynamicNotchHostingClipView(hostingView: view)
            hostingClipView = clipView
            addSubview(clipView)
            needsLayout = true
        }

        override func layout() {
            super.layout()
            updateShapePath()
            hostingClipView?.frame = bounds
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard shapePath?.contains(point) != false else { return nil }

            return super.hitTest(point)
        }

        private func updateShapePath() {
            guard bounds.width > 0, bounds.height > 0 else { return }

            shapePath = shape.path(in: bounds).cgPath
        }
    }

    private final class DynamicNotchHostingClipView: NSView {
        private let hostingView: NSView

        init(hostingView: NSView) {
            self.hostingView = hostingView
            super.init(frame: .zero)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.masksToBounds = true
            addSubview(hostingView)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        override var isFlipped: Bool { true }

        override func layout() {
            super.layout()
            hostingView.frame = bounds
        }
    }
#endif
