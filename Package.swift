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
        // ⏱ Promises and reactive-streams in Swift built for high-performance and scalability.
        .package(url: "https://github.com/vapor/async.git", from: "1.0.0-rc"),

        // 💻 APIs for creating interactive CLI tools.
        .package(url: "https://github.com/vapor/console.git", from: "3.0.0-rc"),

        // 🌎 Utility package containing tools for byte manipulation, Codable, OS APIs, and debugging.
        .package(url: "https://github.com/vapor/core.git", from: "3.0.0-rc"),

        // 🔑 Hashing (BCrypt, SHA, HMAC, etc), encryption, and randomness.
        .package(url: "https://github.com/vapor/crypto.git", from: "3.0.0-rc"),

        // 🗄 Core services for creating database integrations.
        .package(url: "https://github.com/vapor/database-kit.git", from: "1.0.0-rc"),

        // 🚍 High-performance trie-node router.
        .package(url: "https://github.com/vapor/routing.git", from: "3.0.0-rc"),

        // 📦 Dependency injection / inversion of control framework.
        .package(url: "https://github.com/vapor/service.git", from: "1.0.0-rc"),

        // 🚀 Non-blocking, event-driven networking for Swift (HTTP and WebSockets).
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.0.0"),

        // 🖋 Easy-to-use foundation for building powerful templating languages in Swift.
        .package(url: "https://github.com/vapor/template-kit.git", from: "1.0.0-rc"),

        // ✅ Extensible data validation library (email, alphanumeric, UUID, etc)
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
            // "FormURLEncoded",
            "Logging",
            // "Multipart",
            "Routing",
            "Service",
            "TemplateKit",
            "Validation",

            "NIO",
            "NIOHTTP1"
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)
