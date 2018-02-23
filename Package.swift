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
        .library(name: "Vapor", targets: ["Vapor"]),
    ],
    dependencies: [
        // Swift Promises, Futures, and Streams.
        .package(url: "https://github.com/vapor/async.git", from: "1.0.0-rc"),

        // Swift wrapper for Console I/O.
        .package(url: "https://github.com/vapor/console.git", from: "3.0.0-rc"),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", from: "3.0.0-rc"),

        // Cryptography modules
        .package(url: "https://github.com/vapor/crypto.git", from: "3.0.0-rc"),

        // Core services for creating database integrations.
        .package(url: "https://github.com/vapor/database-kit.git", from: "1.0.0-rc"),

        // Non-blocking networking for Swift (HTTP and WebSockets).
        .package(url: "https://github.com/vapor/engine.git", from: "3.0.0-rc"),

        // Easy-to-use foundation for building powerful templating languages in Swift.
        .package(url: "https://github.com/vapor/template-kit.git", from: "1.0.0-rc"),

        // Service container and configuration system.
        .package(url: "https://github.com/vapor/service.git", from: "1.0.0-rc"),

        // Pure Swift (POSIX) TCP and UDP non-blocking socket layer, with event-driven Server and Client.
        .package(url: "https://github.com/vapor/sockets.git", from: "3.0.0-rc"),

        // Swift OpenSSL & macOS Security TLS wrapper
        .package(url: "https://github.com/vapor/tls.git", from: "3.0.0-rc"),

        // Extensible data validation library (email, alphanumeric, UUID, etc)
        .package(url: "https://github.com/vapor/validation.git", from: "2.0.0-rc"),
    ],
    targets: [
        // Boilerplate
        .target(name: "Boilerplate", dependencies: ["Service", "Routing", "Vapor"]),
        .target(name: "BoilerplateRun", dependencies: ["Boilerplate"]),

        // Vapor
        .target(name: "Development", dependencies: ["Vapor"]),
        .target(name: "Vapor", dependencies: [
            "Async",
            "CodableKit",
            "Command",
            "Console",
            "COperatingSystem",
            "Crypto",
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
            "Validation"
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)
