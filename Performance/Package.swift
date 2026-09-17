// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "vapor-performance",
    platforms: [
        .macOS("26.2"),
    ],
    dependencies: [
        .package(name: "vapor", path: ".."),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.14.0"),
        .package(url: "https://github.com/swift-server/swift-http-server.git", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/apple/swift-collections", from: "1.2.1"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "HTTPServerPerformanceServer",
            dependencies: [
                .product(name: "NIOHTTPServer", package: "swift-http-server"),
                .product(name: "BasicContainers", package: "swift-collections"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableUpcomingFeature("LifetimeDependence"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
        .executableTarget(
            name: "PerformanceServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/PerformanceServer",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("ImmutableWeakCaptures"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableUpcomingFeature("LifetimeDependence"),
                .enableUpcomingFeature("ImmutableWeakCaptures"),
            ]
        ),
    ]
)
