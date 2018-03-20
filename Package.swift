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
        // 💻 APIs for creating interactive CLI tools.
        .package(url: "https://github.com/vapor/console.git", .branch("master")),

        // 🌎 Utility package containing tools for byte manipulation, Codable, OS APIs, and debugging.
        .package(url: "https://github.com/vapor/core.git", .branch("master")),

        // 🔑 Hashing (BCrypt, SHA, HMAC, etc), encryption, and randomness.
        .package(url: "https://github.com/vapor/crypto.git", .branch("master")),

        // 🗄 Core services for creating database integrations.
        .package(url: "https://github.com/vapor/database-kit.git", .branch("master")),

        // 🚀 Non-blocking, event-driven networking for Swift (HTTP and WebSockets).
        .package(url: "https://github.com/vapor/engine.git", .branch("master")),

        // 🚍 High-performance trie-node router.
        .package(url: "https://github.com/vapor/routing.git", .branch("master")),

        // 📦 Dependency injection / inversion of control framework.
        .package(url: "https://github.com/vapor/service.git", .branch("master")),

        // 🖋 Easy-to-use foundation for building powerful templating languages in Swift.
        .package(url: "https://github.com/vapor/template-kit.git", .branch("master")),

        // ✅ Extensible data validation library (email, alphanumeric, UUID, etc)
        .package(url: "https://github.com/vapor/validation.git", .branch("master")),
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
            "TemplateKit",
            "Validation",
            "WebSocket"
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)
