// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "vapor-performance",
    platforms: [
        .macOS("26.2"),
    ],
    dependencies: [
        .package(name: "vapor", path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "PerformanceServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources/PerformanceServer",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
    ]
)
