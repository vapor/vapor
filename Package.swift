// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "vapor",
    products: [
        .library(name: "Vapor", targets: ["Vapor"]),
    ],
    dependencies: [
        // 💻 APIs for creating interactive CLI tools.
        .package(url: "https://github.com/vapor/console.git", .branch("master")),

        // 🔑 Hashing (BCrypt, SHA, HMAC, etc), encryption, and randomness.
        .package(url: "https://github.com/vapor/crypto.git", .branch("master")),

        // 🚀 Non-blocking, event-driven HTTP for Swift built on Swift NIO.
        .package(url: "https://github.com/vapor/http.git", .branch("master")),

        // 🚍 High-performance trie-node router.
        .package(url: "https://github.com/vapor/routing.git", .branch("master")),

        // 📦 Dependency injection / inversion of control framework.
        .package(url: "https://github.com/vapor/service.git", .branch("master")),

        // ✅ Extensible data validation library (email, alphanumeric, UUID, etc)
        // .package(url: "https://github.com/vapor/validation.git", from: "2.0.0"),
    ],
    targets: [
        .target(name: "CMultipartParser"),
        
        // Boilerplate
        .target(name: "Boilerplate", dependencies: ["Vapor"]),
        .target(name: "BoilerplateRun", dependencies: ["Boilerplate"]),

        // Vapor
        .target(name: "Development", dependencies: ["Vapor"]),
        .target(name: "Vapor", dependencies: [
            "CMultipartParser",
            "ConsoleKit",
            "CryptoKit",
            "HTTPKit",
            "RoutingKit",
            "ServiceKit",
            // "Validation",
        ]),
        .target(name: "XCTVapor", dependencies: ["Vapor"]),
        .testTarget(name: "VaporTests", dependencies: ["XCTVapor"]),
    ]
)
