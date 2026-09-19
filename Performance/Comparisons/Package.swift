// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "performance-comparisons",
    platforms: [.macOS("26.2")],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", exact: "4.122.1"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", exact: "2.26.0"),
        // Match the current Vapor baseline's hot-path dependencies.
        .package(url: "https://github.com/apple/swift-nio.git", exact: "2.103.0"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.15.1"),
    ],
    targets: [
        .executableTarget(
            name: "Vapor4PerformanceServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ]),
        .executableTarget(
            name: "HummingbirdPerformanceServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ]),
    ]
)
