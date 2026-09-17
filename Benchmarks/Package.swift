// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "vapor-benchmarks",
    platforms: [
        .macOS("26.2"),
    ],
    dependencies: [
        .package(name: "vapor", path: ".."),
        .package(url: "https://github.com/ordo-one/benchmark", exact: "1.36.2"),
    ],
    targets: [
        .executableTarget(
            name: "VaporBenchmarks",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "VaporMacros", package: "vapor"),
                .product(name: "Benchmark", package: "benchmark"),
            ],
            path: "VaporBenchmarks",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableExperimentalFeature("Lifetimes"),
            ],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark"),
            ]
        ),
    ]
)
