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
        .package(url: "https://github.com/vapor/async.git", "1.0.0-beta.1"..<"1.0.0-beta.2"),

        // Swift wrapper for Console I/O.
        .package(url: "https://github.com/vapor/console.git", "3.0.0-beta.1"..<"3.0.0-beta.2"),

        // Core extensions, type-aliases, and functions that facilitate common tasks.
        .package(url: "https://github.com/vapor/core.git", "3.0.0-beta.1"..<"3.0.0-beta.2"),

        // Cryptography modules
        .package(url: "https://github.com/vapor/crypto.git", "3.0.0-beta.1"..<"3.0.0-beta.2"),

        // Core services for creating database integrations.
        .package(url: "https://github.com/vapor/database-kit.git", "1.0.0-beta.2"..<"1.0.0-beta.3"),

        // Non-blocking networking for Swift (HTTP and WebSockets).
        .package(url: "https://github.com/vapor/engine.git", "3.0.0-beta.2"..<"3.0.0-beta.3"),

        // Easy-to-use foundation for building powerful templating languages in Swift.
        .package(url: "https://github.com/vapor/template-kit.git", "1.0.0-beta.1"..<"1.0.0-beta.2"),

        // Service container and configuration system.
        .package(url: "https://github.com/vapor/service.git", "1.0.0-beta.1"..<"1.0.0-beta.2"),

        // Pure Swift (POSIX) TCP and UDP non-blocking socket layer, with event-driven Server and Client.
        .package(url: "https://github.com/vapor/sockets.git", "3.0.0-beta.2"..<"3.0.0-beta.3"),

        // Swift OpenSSL & macOS Security TLS wrapper
        .package(url: "https://github.com/vapor/tls.git", "3.0.0-beta.2"..<"3.0.0-beta.3"),

        // Extensible data validation library (email, alphanumeric, UUID, etc)
        .package(url: "https://github.com/vapor/validation.git", "2.0.0-beta.1"..<"2.0.0-beta.2"),
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
            "Files",
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
