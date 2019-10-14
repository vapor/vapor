// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "vapor",
    products: [
        .library(name: "Vapor", targets: ["Vapor"]),
    ],
    dependencies: [
        // Sugary extensions for the SwiftNIO library
        .package(url: "https://github.com/vapor/async-kit.git", from: "1.0.0-alpha"),

        // 💻 APIs for creating interactive CLI tools.
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.0.0-alpha.2"),

        // 🔑 Hashing (BCrypt, SHA2, HMAC), encryption (AES), public-key (RSA), and random data generation.
        .package(url: "https://github.com/vapor/open-crypto.git", from: "4.0.0-alpha.2"),

        // 🚍 High-performance trie-node router.
        .package(url: "https://github.com/vapor/routing-kit.git", from: "4.0.0-alpha"),
        
        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.2.0"),
        
        // Bindings to OpenSSL-compatible libraries for TLS support in SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),
        
        // HTTP/2 support for SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.0.0"),
        
        // Useful code around SwiftNIO.
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
        
        // Swift logging API
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),

        // HTTP client library built on SwiftNIO
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0-alpha.1"),

        // WebSocket client library built on SwiftNIO
        .package(url: "https://github.com/vapor/websocket-kit.git", .branch("master")),
    ],
    targets: [
        // C helpers
        .target(name: "CBcrypt"),
        .target(name: "CMultipartParser"),
        .target(name: "COperatingSystem"),
        .target(name: "CURLParser"),

        // Vapor
        .target(name: "Vapor", dependencies: [
            "AsyncKit",
            "CBcrypt",
            "CMultipartParser",
            "COperatingSystem",
            "CURLParser",
            "ConsoleKit",
            "Logging",
            "NIO",
            "NIOExtras",
            "NIOFoundationCompat",
            "NIOHTTPCompression",
            "NIOHTTP1",
            "NIOHTTP2",
            "AsyncHTTPClient",
            "NIOSSL",
            "NIOWebSocket",
            "OpenCrypto",
            "RoutingKit",
            "WebSocketKit"
        ]),

        // Development
        .target(name: "Development", dependencies: ["Vapor"]),

        // Testing
        .target(name: "XCTVapor", dependencies: ["Vapor"]),
        .testTarget(name: "VaporTests", dependencies: ["XCTVapor"]),
    ]
)
