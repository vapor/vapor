// swift-tools-version:4.0
import PackageDescription

#if os(macOS)
    let tlsImpl: Target.Dependency = "AppleTLS"
#else
    let tlsImpl: Target.Dependency = "OpenSSL"
#endif

let package = Package(
    name: "Vapor",
    products: [
        .library(name: "Vapor", targets: ["Validation", "Vapor"]),
    ],
    dependencies: [
        // Swift Promises, Futures, and Streams.
        .package(url: "https://github.com/vapor/async.git", .exact("1.0.0-beta.1")),

        // Swift wrapper for Console I/O.
        .package(url: "https://github.com/vapor/console.git", .exact("3.0.0-beta.1")),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", .exact("3.0.0-beta.1")),

        // Cryptography modules
        .package(url: "https://github.com/vapor/crypto.git", .exact("3.0.0-beta.1")),

        // Core services for creating database integrations.
        .package(url: "https://github.com/vapor/database-kit.git", .exact("1.0.0-beta.1")),

        // Non-blocking networking for Swift (HTTP and WebSockets).
        .package(url: "https://github.com/vapor/engine.git", .exact("3.0.0-beta.1")),

        // Easy-to-use foundation for building powerful templating languages in Swift.
        .package(url: "https://github.com/vapor/template-kit.git", .exact("1.0.0-beta.1")),

        // Service container and configuration system.
        .package(url: "https://github.com/vapor/service.git", .exact("1.0.0-beta.1")),

        // Pure Swift (POSIX) TCP and UDP non-blocking socket layer, with event-driven Server and Client.
        .package(url: "https://github.com/vapor/sockets.git", .exact("3.0.0-beta.1")),

        // Swift OpenSSL & macOS Security TLS wrapper
        .package(url: "https://github.com/vapor/tls.git", .exact("3.0.0-beta.1")),
    ],
    targets: [
        // Boilerplate
        .target(name: "Boilerplate", dependencies: ["Service", "Routing", "Vapor"]),
        .target(name: "BoilerplateRun", dependencies: ["Boilerplate"]),


        // Validation
        .target(name: "Validation", dependencies: ["CodableKit"]),
        .testTarget(name: "ValidationTests", dependencies: ["Validation"]),

        // Vapor
        .target(name: "Development", dependencies: ["Vapor"]),
        .target(name: "Vapor", dependencies: [
            "CodableKit",
            "Command",
            "Console",
            "COperatingSystem",
            "DatabaseKit",
            "Debugging",
            "FormURLEncoded",
            "HTTP",
            "Logging",
            "Multipart",
            "Routing",
            "Service",
            "TCP",
            "TemplateKit",
            "TLS",
            tlsImpl,
            "ServerSecurity",
             "WebSocket",
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)
