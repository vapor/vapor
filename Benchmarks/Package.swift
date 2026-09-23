// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "vapor-benchmarks",
    platforms: [
        .macOS("26.2")
    ],
    traits: [
        .trait(name: "AllocationCounting", description: "Build with the allocation counter interposer.")
    ],
    dependencies: [
        .package(name: "vapor", path: ".."),
        .package(
            url: "https://github.com/ordo-one/benchmark", exact: "1.36.2",
            traits: [.trait(name: "MallocInterposer", condition: .when(traits: ["AllocationCounting"]))]),
        .package(url: "https://github.com/swift-server/async-http-client.git", exact: "1.35.0"),
        // Async Algorithms 1.1.5 uses preview APIs removed in Collections 1.7.0.
        .package(url: "https://github.com/apple/swift-collections", exact: "1.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "VaporBenchmarks",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "VaporMacros", package: "vapor"),
                .product(name: "Benchmark", package: "benchmark"),
            ],
            path: "VaporBenchmarks",
            swiftSettings: [
                .define("BENCHMARK_ALLOCATION_COUNTING", .when(traits: ["AllocationCounting"])),
                .enableUpcomingFeature("ExistentialAny"),
                .enableExperimentalFeature("Lifetimes"),
            ],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        )
    ]
)
