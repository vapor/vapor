// swift-tools-version:6.2
import PackageDescription

// Kept as a separate package so the benchmark dependencies don't end up in Vapor's own manifest and
// downstream consumers never have to resolve them.
//
// Run all benchmarks:  swift package --disable-sandbox benchmark
// Run one area:        swift package --disable-sandbox benchmark --filter 'routing/.*'
// Baselines:           swift package --disable-sandbox benchmark baseline update main
//                      swift package --disable-sandbox benchmark baseline compare main
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
