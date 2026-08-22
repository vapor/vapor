// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "vapor-benchmarks",
    platforms: [
        .macOS("26.2"),
    ],
    dependencies: [
        .package(name: "vapor", path: ".."),
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.9.2"),
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
            ],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark"),
            ]
        ),
    ]
)
