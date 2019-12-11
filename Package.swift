// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "vapor",
    platforms: [
       .macOS(.v10_14)
    ],
    products: [
        .library(name: "Vapor", targets: ["Vapor"]),
        .library(name: "XCTVapor", targets: ["XCTVapor"])
    ],
    dependencies: [
        // HTTP client library built on SwiftNIO
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
    
        // Sugary extensions for the SwiftNIO library
        .package(url: "https://github.com/vapor/async-kit.git", from: "1.0.0-beta.2"),

        // APIs for creating interactive CLI tools.
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.0.0-beta.2"),

        // Parses and serializes multipart-encoded data with Codable support.
        .package(url: "https://github.com/vapor/multipart-kit.git", from: "4.0.0-beta.2"),

        // Hashing (BCrypt, SHA2, HMAC), encryption (AES), public-key (RSA), and random data generation.
        .package(url: "https://github.com/vapor/open-crypto.git", from: "4.0.0-beta.2"),

        // High-performance trie-node router.
        .package(url: "https://github.com/vapor/routing-kit.git", from: "4.0.0-beta.2"),

        // Swift logging API
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        
        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.2.0"),

        // Useful code around SwiftNIO.
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),

        // HTTP/2 support for SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.0.0"),
        
        // Bindings to OpenSSL-compatible libraries for TLS support in SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),

        // Extensions for SwiftNIO to support Apple platforms as first-class citizens.
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.0.0"),

        // WebSocket client library built on SwiftNIO
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0-beta.2"),
    ],
    targets: [
        // C helpers
        .target(name: "CBcrypt"),
        .target(name: "COperatingSystem"),
        .target(name: "CURLParser"),

        // Vapor
        .target(name: "Vapor", dependencies: [
            "AsyncHTTPClient",
            "AsyncKit",
            "CBcrypt",
            "COperatingSystem",
            "CURLParser",
            "ConsoleKit",
            "Logging",
            "MultipartKit",
            "NIO",
            "NIOExtras",
            "NIOFoundationCompat",
            "NIOHTTPCompression",
            "NIOHTTP1",
            "NIOHTTP2",
            "NIOSSL",
            "NIOTransportServices",
            "NIOWebSocket",
            "OpenCrypto",
            "RoutingKit",
            "WebSocketKit",
        ]),

        // Development
        .target(name: "Development", dependencies: ["Vapor"]),

        // Testing
        .target(name: "XCTVapor", dependencies: ["Vapor"]),
        .testTarget(name: "VaporTests", dependencies: ["XCTVapor"]),
    ]
)
