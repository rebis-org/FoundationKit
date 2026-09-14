#if os(macOS)
    public import CoreGraphics
    import AppKit

    let dynamicNotchEdgeRailWidth: CGFloat = 5
    let dynamicNotchAttachedEdgeRailWidth: CGFloat = 3

    func clamped(_ value: CGFloat?, or defaultValue: CGFloat, atLeast minimum: CGFloat = 0) -> CGFloat {
        guard let value, value.isFinite else { return defaultValue }
        return max(minimum, value)
    }

    public enum DynamicNotchDirection: CaseIterable, Identifiable, Sendable {
        case top
        case bottom
        case left
        case right

        public var id: Self { self }
    }

    public enum DynamicNotchEdgeAlignment: CaseIterable, Identifiable, Sendable {
        case start
        case center
        case end

        public var id: Self { self }
    }

    public enum DynamicNotchPlacement: Equatable, Sendable {
        case edge(
            DynamicNotchDirection,
            alignment: DynamicNotchEdgeAlignment = .center,
            offset: CGFloat = 0
        )

        public var direction: DynamicNotchDirection {
            switch self {
            case let .edge(direction, _, _):
                return direction
            }
        }
    }

    public enum DynamicNotchPresentationMode: CaseIterable, Identifiable, Sendable {
        case compact
        case expanded

        public var id: Self { self }
    }

    public struct DynamicNotchConfiguration: Equatable, Sendable {
        public var direction: DynamicNotchDirection
        public var width: CGFloat
        public var height: CGFloat
        public var shoulderRadius: CGFloat
        public var cornerRadius: CGFloat
        public var attachedEdgeRail: CGFloat

        public init(
            direction: DynamicNotchDirection = .top,
            width: CGFloat,
            height: CGFloat,
            cornerRadius: CGFloat? = nil,
            shoulderRadius: CGFloat? = nil,
            attachedEdgeRail: CGFloat? = nil
        ) {
            self.direction = direction
            self.width = clamped(width, or: 1, atLeast: 1)
            self.height = clamped(height, or: 1, atLeast: 1)

            let maximumCornerRadius = min(self.width, self.height) / 2
            let maximumShoulderRadius = min(self.width, self.height) / 4
            self.cornerRadius = min(
                clamped(cornerRadius ?? min(24, maximumCornerRadius), or: 0),
                maximumCornerRadius
            )
            self.shoulderRadius = min(
                clamped(shoulderRadius ?? cornerRadius ?? min(30, maximumShoulderRadius), or: 0),
                maximumShoulderRadius
            )

            // Top and bottom notches default to a 3pt rail; side notches do not
            // add another rail because their existing vertical rails already
            // protect the exposed shoulders.
            let (defaultRail, maximumRail): (CGFloat, CGFloat) = switch direction {
            case .top, .bottom:
                (dynamicNotchAttachedEdgeRailWidth, max(0, self.height - 1))

            case .left, .right:
                (0, max(0, self.width - 1))
            }
            self.attachedEdgeRail = min(
                clamped(attachedEdgeRail ?? defaultRail, or: 0),
                maximumRail
            )
        }
    }

    enum DynamicNotchSafeAreaResolver {
        static func attachedEdgeRail(
            for direction: DynamicNotchDirection,
            override: CGFloat?,
            safeAreaInsets: NSEdgeInsets
        ) -> CGFloat {
            if let override {
                return clamped(override, or: 0)
            }

            switch direction {
            case .top:
                return max(dynamicNotchAttachedEdgeRailWidth, safeAreaInsets.top)

            case .bottom:
                return max(dynamicNotchAttachedEdgeRailWidth, safeAreaInsets.bottom)

            case .left, .right:
                return 0
            }
        }

        static func compactHeight(
            override: CGFloat?,
            statusBarThickness: CGFloat,
            safeAreaInsets: NSEdgeInsets
        ) -> CGFloat {
            if let override {
                return clamped(override, or: 1, atLeast: 1)
            }

            return max(1, statusBarThickness, safeAreaInsets.top)
        }

        static func compactCenterGap(
            override: CGFloat?,
            auxiliaryTopLeftArea: CGRect?,
            auxiliaryTopRightArea: CGRect?
        ) -> CGFloat {
            if let override {
                return clamped(override, or: 0)
            }

            guard
                let auxiliaryTopLeftArea,
                let auxiliaryTopRightArea
            else {
                return 0
            }

            return max(0, auxiliaryTopRightArea.minX - auxiliaryTopLeftArea.maxX)
        }
    }

    enum DynamicNotchWindowGeometry {
        static func frame(
            for configuration: DynamicNotchConfiguration,
            placement: DynamicNotchPlacement,
            in screenFrame: CGRect
        ) -> CGRect {
            switch placement {
            case let .edge(direction, alignment, offset):
                switch direction {
                case .top, .bottom:
                    let available = max(0, screenFrame.width - configuration.width)
                    let distanceFromStart = clampedDistance(
                        available: available,
                        alignment: alignment,
                        offset: offset
                    )
                    return CGRect(
                        x: screenFrame.minX + distanceFromStart,
                        y: direction == .top
                            ? screenFrame.maxY - configuration.height
                            : screenFrame.minY,
                        width: configuration.width,
                        height: configuration.height
                    )

                case .left, .right:
                    let available = max(0, screenFrame.height - configuration.height)
                    let distanceFromTop = clampedDistance(
                        available: available,
                        alignment: alignment,
                        offset: offset
                    )
                    return CGRect(
                        x: direction == .left
                            ? screenFrame.minX
                            : screenFrame.maxX - configuration.width,
                        y: screenFrame.maxY - configuration.height - distanceFromTop,
                        width: configuration.width,
                        height: configuration.height
                    )
                }
            }
        }

        private static func clampedDistance(
            available: CGFloat,
            alignment: DynamicNotchEdgeAlignment,
            offset: CGFloat
        ) -> CGFloat {
            let base: CGFloat
            switch alignment {
            case .start:
                base = 0

            case .center:
                base = available / 2

            case .end:
                base = available
            }

            let finiteOffset = offset.isFinite ? offset : 0
            return min(max(0, base + finiteOffset), available)
        }
    }
#endif
