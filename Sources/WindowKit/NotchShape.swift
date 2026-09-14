#if os(macOS)
    #if OpenSwiftUI
        public import OpenSwiftUI

        // OpenSwiftUI 0.21.0 has no ContentBuilder; ViewBuilder covers the same view-closure shapes.
        public typealias ContentBuilder = ViewBuilder
    #else
        public import SwiftUI
    #endif

    extension DynamicNotchConfiguration {
        var shape: DynamicNotchShape {
            DynamicNotchShape(
                direction: direction,
                cornerRadius: cornerRadius,
                shoulderRadius: shoulderRadius
            )
        }
    }

    // An edge-attached outer lip with curved shoulder transitions and a rounded
    // exposed edge. The window controller reuses this shape for hit testing.
    public struct DynamicNotchShape: Shape {
        public var direction: DynamicNotchDirection
        public var shoulderRadius: CGFloat
        public var cornerRadius: CGFloat

        public init(
            direction: DynamicNotchDirection = .top,
            cornerRadius: CGFloat,
            shoulderRadius: CGFloat? = nil
        ) {
            self.direction = direction
            self.shoulderRadius = max(0, shoulderRadius ?? cornerRadius)
            self.cornerRadius = max(0, cornerRadius)
        }

        public func path(in rect: CGRect) -> Path {
            guard rect.width > 0, rect.height > 0 else { return Path() }

            let canonicalWidth: CGFloat
            let canonicalHeight: CGFloat
            switch direction {
            case .top, .bottom:
                canonicalWidth = rect.width
                canonicalHeight = rect.height

            case .left, .right:
                // The canonical path is top-attached. For side directions, its
                // along-edge and inward dimensions are swapped before
                // transforming it into the destination rectangle.
                canonicalWidth = rect.height
                canonicalHeight = rect.width
            }

            let shoulder = min(
                shoulderRadius,
                canonicalWidth / 4,
                canonicalHeight / 4
            )
            let exposed = min(
                cornerRadius,
                canonicalWidth / 4,
                canonicalHeight / 2
            )

            let canonicalPath = Self.topPath(
                in: CGRect(x: 0, y: 0, width: canonicalWidth, height: canonicalHeight),
                shoulder: shoulder,
                exposed: exposed
            )

            switch direction {
            case .top:
                return canonicalPath.applying(
                    CGAffineTransform(translationX: rect.minX, y: rect.minY)
                )

            case .bottom:
                return canonicalPath.applying(
                    CGAffineTransform(
                        a: 1,
                        b: 0,
                        c: 0,
                        d: -1,
                        tx: rect.minX,
                        ty: rect.maxY
                    )
                )

            case .left:
                return canonicalPath.applying(
                    CGAffineTransform(
                        a: 0,
                        b: 1,
                        c: 1,
                        d: 0,
                        tx: rect.minX,
                        ty: rect.minY
                    )
                )

            case .right:
                return canonicalPath.applying(
                    CGAffineTransform(
                        a: 0,
                        b: 1,
                        c: -1,
                        d: 0,
                        tx: rect.maxX,
                        ty: rect.minY
                    )
                )
            }
        }

        // The attached edge is the widest part of the surface. Each side curves
        // inward into the narrower body before the exposed bottom corners begin.
        private static func topPath(
            in rect: CGRect,
            shoulder: CGFloat,
            exposed: CGFloat
        ) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder),
                control: CGPoint(x: rect.minX + shoulder, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY - exposed))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + shoulder + exposed, y: rect.maxY),
                control: CGPoint(x: rect.minX + shoulder, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - shoulder - exposed, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - exposed),
                control: CGPoint(x: rect.maxX - shoulder, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.maxX - shoulder, y: rect.minY)
            )
            path.closeSubpath()
            return path
        }
    }

    enum DynamicNotchContentGeometry {
        static func curveSafeInsets(
            for configuration: DynamicNotchConfiguration
        ) -> EdgeInsets {
            // Keep the rectangular content boundary inside both the inward
            // shoulder and the rounded exposed corner. The attached-edge rail
            // owns vertical placement for top/bottom notches, so no
            // opposite-side padding is introduced here.
            let alongEdgeInset = configuration.shoulderRadius + configuration.cornerRadius

            switch configuration.direction {
            case .top, .bottom:
                return EdgeInsets(
                    top: 0,
                    leading: alongEdgeInset,
                    bottom: 0,
                    trailing: alongEdgeInset
                )

            case .left, .right:
                return EdgeInsets(
                    top: alongEdgeInset,
                    leading: 0,
                    bottom: alongEdgeInset,
                    trailing: 0
                )
            }
        }
    }

    struct NotchSurface<Content: View>: View {
        private let configuration: DynamicNotchConfiguration
        private let background: Color
        private let content: Content

        init(
            _ configuration: DynamicNotchConfiguration,
            background: Color,
            @ContentBuilder content: () -> Content
        ) {
            self.configuration = configuration
            self.background = background
            self.content = content()
        }

        var body: some View {
            let shape = configuration.shape

            ZStack {
                shape.fill(background)

                content
            }
            .frame(width: configuration.width, height: configuration.height)
            .clipShape(shape)
            #if !OpenSwiftUI
                .contentShape(shape)
            #endif
        }
    }
#endif
