// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "MiddlewareServices",
    platforms: [.macOS("26.2")],
    dependencies: [
        .package(name: "vapor", path: "../.."),
        .package(url: "https://github.com/vapor/fluent-kit.git", from: "1.56.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.14.0"),
    ],
    targets: [
        .target(
            name: "MiddlewareServices",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "VaporMacros", package: "vapor"),
                .product(name: "FluentKit", package: "fluent-kit"),
                .product(name: "Logging", package: "swift-log"),
            ]
        )
    ]
)
