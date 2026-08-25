// swift-tools-version: 6.4

import CompilerPluginSupport
import PackageDescription

private enum Constants {
    static let swiftSettings: [SwiftSetting] = [
        .treatAllWarnings(as: .error),
        .strictMemorySafety(),
        .enableExperimentalFeature("AccessLevelOnImport"),
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
    ]
}

let package = Package(
    name: "FoundationKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
        .macCatalyst(.v16),
    ],
    products: [
        .library(name: "PrimitiveKit", targets: ["PrimitiveKit"]),
        .library(name: "InfraKit", targets: ["InfraKit"]),
        .library(name: "LogKit", targets: ["LogKit"]),
        .library(name: "ErrKit", targets: ["ErrKit"]),
        .library(name: "PathKit", targets: ["PathKit"]),
        .library(name: "FileKit", targets: ["FileKit"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git", "509.0.0" ..< "605.0.0",
        ),
        .package(
            url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0",
        ),
    ],
    targets: [
        .target(
            name: "PrimitiveKit",
            dependencies: [],
            swiftSettings: Constants.swiftSettings,
        ),
        .target(
            name: "InfraKit",
            dependencies: [],
            swiftSettings: Constants.swiftSettings,
        ),
        .target(
            name: "LogKit",
            dependencies: ["InfraKit", "LogKitMacros"],
            swiftSettings: Constants.swiftSettings,
        ),
        .target(
            name: "ErrKit",
            dependencies: ["LogKit"],
            swiftSettings: Constants.swiftSettings,
        ),
        .target(
            name: "PathKit",
            dependencies: [],
            swiftSettings: Constants.swiftSettings,
        ),
        .target(
            name: "FileKit",
            dependencies: ["InfraKit", "PathKit", "LogKit", "ErrKit"],
            swiftSettings: Constants.swiftSettings,
        ),
        .macro(
            name: "LogKitMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ],
            path: "Macros/LogKit",
            swiftSettings: Constants.swiftSettings,
        ),
    ],
    swiftLanguageModes: [.v6],
)
