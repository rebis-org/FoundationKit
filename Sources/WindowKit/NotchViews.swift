#if os(macOS)
    #if OpenSwiftUI
        public import OpenSwiftUI
    #else
        public import SwiftUI
    #endif

    public struct DynamicNotch<Content: View>: View {
        private let configuration: DynamicNotchConfiguration
        private let background: Color
        private let contentInsets: EdgeInsets
        private let content: () -> Content

        public init(
            direction: DynamicNotchDirection = .top,
            width: CGFloat,
            height: CGFloat,
            cornerRadius: CGFloat? = nil,
            shoulderRadius: CGFloat? = nil,
            attachedEdgeRail: CGFloat? = nil,
            background: Color = .black,
            contentInsets: EdgeInsets = EdgeInsets(),
            @ContentBuilder content: @escaping () -> Content,
        ) {
            configuration = DynamicNotchConfiguration(
                direction: direction,
                width: width,
                height: height,
                cornerRadius: cornerRadius,
                shoulderRadius: shoulderRadius,
                attachedEdgeRail: attachedEdgeRail,
            )
            self.background = background
            self.contentInsets = contentInsets
            self.content = content
        }

        public var body: some View {
            NotchSurface(configuration, background: background) {
                contentBoundary
            }
        }

        // The content cannot use the full outer rectangle: at the shoulder
        // transitions that rectangle includes pixels outside the notch body.
        // Keep the body finite and reserve fixed rails so intrinsic SwiftUI
        // views cannot negotiate an ideal width past the curve.
        @ContentBuilder private var contentBoundary: some View {
            Group {
                switch configuration.direction {
                case .top:
                    VStack(spacing: 0) {
                        attachedEdgeRail
                        horizontalContentBoundary(height: horizontalBodyHeight)
                    }

                case .bottom:
                    VStack(spacing: 0) {
                        horizontalContentBoundary(height: horizontalBodyHeight)
                        attachedEdgeRail
                    }

                case .left, .right:
                    VStack(spacing: 0) {
                        edgeRail
                            .frame(width: interiorWidth, height: dynamicNotchEdgeRailWidth)

                        contentBody(width: interiorWidth, height: sideBodyHeight)

                        edgeRail
                            .frame(width: interiorWidth, height: dynamicNotchEdgeRailWidth)
                    }
                }
            }
            .frame(width: interiorWidth, height: interiorHeight, alignment: .topLeading)
            .padding(curveSafeInsets)
            .frame(
                width: configuration.width,
                height: configuration.height,
                alignment: .topLeading,
            )
            .clipped()
        }

        private func horizontalContentBoundary(height: CGFloat) -> some View {
            HStack(spacing: 0) {
                edgeRail
                    .frame(width: dynamicNotchEdgeRailWidth, height: height)

                contentBody(width: horizontalBodyWidth, height: height)

                edgeRail
                    .frame(width: dynamicNotchEdgeRailWidth, height: height)
            }
            .frame(width: interiorWidth, height: height, alignment: .center)
        }

        private var attachedEdgeRail: some View {
            Color.clear
                .frame(width: interiorWidth, height: configuration.attachedEdgeRail)
        }

        private var edgeRail: some View {
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func contentBody(width: CGFloat, height: CGFloat) -> some View {
            let contentWidth = max(
                1,
                width - contentInsets.leading - contentInsets.trailing,
            )
            let contentHeight = max(
                1,
                height - contentInsets.top - contentInsets.bottom,
            )

            return content()
                .frame(width: contentWidth, height: contentHeight, alignment: .center)
                .padding(contentInsets)
                .frame(width: width, height: height, alignment: .center)
                .clipped()
        }

        private var interiorWidth: CGFloat {
            max(
                1,
                configuration.width - curveSafeInsets.leading - curveSafeInsets.trailing,
            )
        }

        private var interiorHeight: CGFloat {
            max(
                1,
                configuration.height - curveSafeInsets.top - curveSafeInsets.bottom,
            )
        }

        private var horizontalBodyWidth: CGFloat {
            max(1, interiorWidth - (dynamicNotchEdgeRailWidth * 2))
        }

        private var horizontalBodyHeight: CGFloat {
            max(1, interiorHeight - configuration.attachedEdgeRail)
        }

        private var sideBodyHeight: CGFloat {
            max(1, interiorHeight - (dynamicNotchEdgeRailWidth * 2))
        }

        // The body starts after the inward shoulder curves and stays clear of
        // the rounded exposed edge. The values are directional because side
        // notches need vertical protection while top/bottom notches need
        // horizontal protection.
        private var curveSafeInsets: EdgeInsets {
            DynamicNotchContentGeometry.curveSafeInsets(for: configuration)
        }
    }

    public struct DynamicNotchCompact<Leading: View, Trailing: View>: View {
        private let configuration: DynamicNotchConfiguration
        private let centerGap: CGFloat
        private let background: Color
        private let contentInsets: EdgeInsets
        private let leading: () -> Leading
        private let trailing: () -> Trailing

        public init(
            direction: DynamicNotchDirection = .top,
            width: CGFloat,
            height: CGFloat,
            centerGap: CGFloat,
            cornerRadius: CGFloat? = nil,
            shoulderRadius: CGFloat? = nil,
            background: Color = .black,
            contentInsets: EdgeInsets = EdgeInsets(),
            @ContentBuilder leading: @escaping () -> Leading,
            @ContentBuilder trailing: @escaping () -> Trailing,
        ) {
            configuration = DynamicNotchConfiguration(
                direction: direction,
                width: width,
                height: height,
                cornerRadius: cornerRadius,
                shoulderRadius: shoulderRadius,
                attachedEdgeRail: 0,
            )
            self.centerGap = clamped(centerGap, or: 0)
            self.background = background
            self.contentInsets = contentInsets
            self.leading = leading
            self.trailing = trailing
        }

        public var body: some View {
            NotchSurface(configuration, background: background) {
                HStack(spacing: 0) {
                    leading()
                        .frame(
                            width: sideLaneWidth,
                            height: contentHeight,
                            alignment: .trailing,
                        )
                        .clipped()

                    Color.clear
                        .frame(width: resolvedCenterGap, height: contentHeight)

                    trailing()
                        .frame(
                            width: sideLaneWidth,
                            height: contentHeight,
                            alignment: .leading,
                        )
                        .clipped()
                }
                .frame(width: contentWidth, height: contentHeight)
                .padding(contentInsets)
                .frame(
                    width: contentFrameWidth,
                    height: configuration.height,
                    alignment: .center,
                )
            }
        }

        private var outerHorizontalInset: CGFloat {
            configuration.shoulderRadius
                + configuration.cornerRadius
                + dynamicNotchEdgeRailWidth
        }

        private var contentWidth: CGFloat {
            max(
                1,
                contentFrameWidth
                    - contentInsets.leading
                    - contentInsets.trailing,
            )
        }

        private var contentFrameWidth: CGFloat {
            max(1, configuration.width - (outerHorizontalInset * 2))
        }

        private var contentHeight: CGFloat {
            max(
                1,
                configuration.height - contentInsets.top - contentInsets.bottom,
            )
        }

        private var resolvedCenterGap: CGFloat {
            min(centerGap, contentWidth)
        }

        private var sideLaneWidth: CGFloat {
            max(0, (contentWidth - resolvedCenterGap) / 2)
        }
    }
#endif
