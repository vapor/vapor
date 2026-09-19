// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "vapor-benchmarks",
    platforms: [
        .macOS("26.2")
    ],
    dependencies: [
        .package(name: "vapor", path: ".."),
        .package(url: "https://github.com/ordo-one/benchmark", exact: "1.36.2"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", exact: "2.26.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", exact: "1.35.0"),
        .package(url: "https://github.com/swift-server/swift-http-server.git", .upToNextMinor(from: "0.2.0")),
    ],
    targets: [
        .target(
            name: "BenchmarkSupport",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Benchmark", package: "benchmark"),
            ], path: "BenchmarkSupport"),
        .executableTarget(
            name: "RawHTTPServerBenchmarks",
            dependencies: [
                "BenchmarkSupport",
                .product(name: "NIOHTTPServer", package: "swift-http-server"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Benchmark", package: "benchmark"),
            ],
            path: "RawHTTPServerBenchmarks",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny"), .enableExperimentalFeature("Lifetimes")],
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "HummingbirdBenchmarks",
            dependencies: [
                "BenchmarkSupport",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Benchmark", package: "benchmark"),
            ],
            path: "HummingbirdBenchmarks",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "VaporBenchmarks",
            dependencies: [
                "BenchmarkSupport",
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
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        ),
    ]
)
