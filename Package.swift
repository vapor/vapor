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

        // HTTP client library built on SwiftNIO
        .package(url: "https://github.com/swift-server/swift-nio-http-client.git", .branch("master")),

        // SwiftNIO based WebSocket client
        .package(url: "https://github.com/vapor/nio-websocket-client.git", .branch("master")),
    ],
    targets: [
        // C helpers
        .target(name: "CMultipartParser"),
        .target(name: "COperatingSystem"),

        // Vapor
        .target(name: "Vapor", dependencies: [
            "CMultipartParser",
            "COperatingSystem",
            "ConsoleKit",
            "CryptoKit",
            "Logging",
            "NIO",
            "NIOExtras",
            "NIOFoundationCompat",
            "NIOHTTPCompression",
            "NIOHTTP1",
            "NIOHTTP2",
            "NIOHTTPClient",
            "NIOSSL",
            "NIOWebSocket",
            "NIOWebSocketClient",
            "RoutingKit",
        ]),

        // Development
        .target(name: "Development", dependencies: ["Vapor"]),

        // Testing
        .target(name: "XCTVapor", dependencies: ["Vapor"]),
        .testTarget(name: "VaporTests", dependencies: ["XCTVapor"]),
    ]
)
