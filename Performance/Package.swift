// swift-tools-version:6.4
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
