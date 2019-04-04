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

        // 🚍 High-performance trie-node router.
        .package(url: "https://github.com/vapor/routing.git", .branch("master")),

        // 📦 Dependency injection / inversion of control framework.
        .package(url: "https://github.com/vapor/service.git", .branch("master")),
        
        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        
        // Bindings to OpenSSL-compatible libraries for TLS support in SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),
        
        // HTTP/2 support for SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.0.0"),
        
        // Useful code around SwiftNIO.
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
        
        // Swift logging API
        .package(url: "https://github.com/apple/swift-log.git", .branch("master")),

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
            "Logging",
            "NIO",
            "NIOExtras",
            "NIOFoundationCompat",
            "NIOHTTPCompression",
            "NIOHTTP1",
            "NIOHTTP2",
            "NIOSSL",
            "NIOWebSocket",
            "RoutingKit",
            "ServiceKit",
            // "Validation",
        ]),
        .target(name: "XCTVapor", dependencies: ["Vapor"]),
        .testTarget(name: "VaporTests", dependencies: ["XCTVapor"]),
    ]
)
