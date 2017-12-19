// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Vapor",
    products: [
        .library(name: "Vapor", targets: ["Validation", "Vapor"]),
    ],
    dependencies: [
        // Swift Promises, Futures, and Streams.
        .package(url: "https://github.com/vapor/async.git", .branch("beta")),

        // Swift wrapper for Console I/O.
        .package(url: "https://github.com/vapor/console.git", .branch("beta")),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", .branch("beta")),

        // Cryptography modules
        .package(url: "https://github.com/vapor/crypto.git", .branch("beta")),

        // Non-blocking networking for Swift (HTTP and WebSockets).
        .package(url: "https://github.com/vapor/engine.git", .branch("beta")),

        // Service container and configuration system.
        .package(url: "https://github.com/vapor/service.git", .branch("beta")),
    ],
    targets: [
        // Boilerplate
        .target(name: "Boilerplate", dependencies: ["Fluent", "Service", "Routing", "Vapor"]),
        .target(name: "BoilerplateRun", dependencies: ["Boilerplate"]),


        // Validation
        .target(name: "Validation", dependencies: ["CodableKit"]),
        .testTarget(name: "ValidationTests", dependencies: ["Validation"]),

        // Vapor
        .target(name: "Development", dependencies: ["Fluent", "FluentSQLite", "Leaf", "Vapor", "SQLite"]),
        .target(name: "Vapor", dependencies: [
            "Command",
            "Console",
            "COperatingSystem",
            "Debugging",
            "FormURLEncoded",
            "HTTP",
            "Leaf",
            "Logging",
            "Multipart",
            "Routing",
            "Service",
            "TCP",
            "TLS",
            "ServerSecurity",
             "WebSocket",
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)


