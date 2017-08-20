// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Vapor",
    products: [
        .library(name: "Vapor", targets: ["Vapor"]),
    ],
    dependencies: [
        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", .branch("beta")),

        // A library to aid users with better debugging.
        .package(url: "https://github.com/vapor/debugging.git", .branch("beta")),

        // Networking layer.
        .package(url: "https://github.com/vapor/engine.git", .branch("beta")),

        // Service container and configuration system.
        .package(url: "https://github.com/vapor/service.git", .branch("beta")),
    ],
    targets: [
        .target(name: "Development", dependencies: ["Vapor"]),
        .target(name: "Vapor", dependencies: [
            "Core",
            "Debugging",
            "HTTP", 
            "Service",
            "TCP",
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)
