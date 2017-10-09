// swift-tools-version:4.0
import PackageDescription

#if os(macOS) || os(iOS)
    let ssl: Target.Dependency = "AppleSSL"
#else
    let ssl: Target.Dependency = "OpenSSL"
#endif

let package = Package(
    name: "Vapor",
    products: [
        // Core
        .library(name: "Async", targets: ["Async"]),
        .library(name: "Bits", targets: ["Bits"]),
        .library(name: "Core", targets: ["Core"]),
        .library(name: "libc", targets: ["libc"]),

        // Crypto
        .library(name: "Crypto", targets: ["Crypto"]),

        // Debugging
        .library(name: "Debugging", targets: ["Debugging"]),

        // Fluent
        // .library(name: "Fluent", targets: ["Fluent"]),

        // JWT
        .library(name: "JWT", targets: ["JWT"]),

        // Leaf
        .library(name: "Leaf", targets: ["Leaf"]),

        // Logging
        .library(name: "Logging", targets: ["Logging"]),

        // MySQL
        .library(name: "MySQL", targets: ["MySQL"]),

        // Net
        .library(name: "HTTP", targets: ["HTTP"]),
        .library(name: "HTTP2", targets: ["HTTP2"]),
        .library(name: "TCP", targets: ["TCP"]),

        // Random
        .library(name: "Random", targets: ["Random"]),

        // Routing
        .library(name: "Routing", targets: ["Routing"]),

        // Service
        .library(name: "Service", targets: ["Service"]),

        // SQLite
        .library(name: "SQLite", targets: ["SQLite"]),
        
        // TLS/SSL
        .library(name: "TLS", targets: ["TLS"]),

        // Vapor
        .library(name: "Vapor", targets: ["Vapor"]),
        
        // WebSockets
        .library(name: "WebSocket", targets: ["WebSocket"]),
    ],
    dependencies: [],
    targets: [
        // Async
        .target(name: "Async"),
        .testTarget(name: "AsyncTests", dependencies: ["Async"]),

        // Bits
        .target(name: "Bits"),

        // Core
        .target(name: "Core", dependencies: ["libc", "Debugging"]),
        .target(name: "libc"),
        
        // Crypto
        .target(name: "Crypto", dependencies: ["libc", "Async", "Bits", "Core", "Debugging"]),
        .testTarget(name: "CryptoTests", dependencies: ["Crypto"]),

        // Debugging
        .target(name: "Debugging"),
        .testTarget(name: "DebuggingTests", dependencies: ["Debugging"]),

        // Debugging
//        .target(name: "Fluent", dependencies: ["SQLite"]),
//        .testTarget(name: "FluentTests", dependencies: ["Fluent"]),

        // JWT
        .target(name: "JWT", dependencies: ["Crypto"]),
        .testTarget(name: "JWTTests", dependencies: ["JWT"]),

        // Leaf
        .target(name: "Leaf", dependencies: ["Core", "Service"]),
        .testTarget(name: "LeafTests", dependencies: ["Leaf"]),

        // Logging
        .target(name: "Logging", dependencies: ["Core", "Service"]),
        .testTarget(name: "LoggingTests", dependencies: ["Logging"]),

        // MySQL
        .target(name: "MySQL", dependencies: ["TCP", "Crypto"]),
        .testTarget(name: "MySQLTests", dependencies: ["MySQL"]),
        
        // MySQL
        .target(name: "Multipart", dependencies: ["Core", "Debugging", "HTTP"]),
        .testTarget(name: "MultipartTests", dependencies: ["Multipart"]),

        // Net
        .target(name: "CHTTP"),
        .target(name: "HTTP", dependencies: ["CHTTP", "TCP"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "TCP", dependencies: ["Debugging", "Async", "libc"]),
        .testTarget(name: "TCPTests", dependencies: ["TCP"]),
        
        // HTTP/2
        .target(name: "HTTP2", dependencies: ["HTTP", "TLS", "Pufferfish"]),
        .testTarget(name: "HTTP2Tests", dependencies: ["HTTP2"]),

        // Random crypto
        .target(name: "Random", dependencies: ["Core"]),
        .testTarget(name: "RandomTests", dependencies: ["Random"]),
        
        // Compression
        .target(name: "Pufferfish", dependencies: ["Pufferfish"]),
        .testTarget(name: "PufferfishTests", dependencies: ["Pufferfish"]),

        // Routing
        .target(name: "Routing", dependencies: ["Core", "Debugging", "HTTP", "WebSocket"]),
        .testTarget(name: "RoutingTests", dependencies: ["Routing"]),

        // Service
        .target(name: "Service", dependencies: ["Core", "Debugging"]),
        .testTarget(name: "ServiceTests", dependencies: ["Service"]),

        // TLS
        .target(name: "TLS", dependencies: [ssl, "TCP"]),
        .testTarget(name: "TLSTests", dependencies: ["TLS"]),

        // SQLite
        .target(name: "CSQLite"),
        .target(name: "SQLite", dependencies: ["Core", "CSQLite", "Debugging"]),
        .testTarget(name: "SQLiteTests", dependencies: ["SQLite"]),

        // Vapor
        .target(name: "Development", dependencies: ["Leaf", "Vapor", "MySQL", "SQLite"]),
        .target(name: "Vapor", dependencies: [
            "Core",
            "Debugging",
            "HTTP",
            "Leaf",
            "Routing",
            "Service",
            "TCP",
            "WebSocket"
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),

        // WebSocket
        .target(name: "WebSocket", dependencies: ["Core", "Debugging", "TCP", "HTTP", "Crypto"]),
        .testTarget(name: "WebSocketTests", dependencies: ["WebSocket"]),
    ]
)

#if os(macOS) || os(iOS)
    package.targets.append(
        .target(name: "AppleSSL", dependencies: ["Async", "Bits", "Debugging"])
    )
    
    package.products.append(
        .library(name: "AppleSSL", targets: ["AppleSSL"])
    )
#else
    package.dependencies.append(
        .package(url: "https://github.com/vapor/copenssl.git", .revision("master"))
    )
    
    package.targets.append(
        .target(name: "OpenSSL", dependencies: ["COpenSSL", "Async", "Debugging"])
    )
    
    package.products.append(
        .library(name: "OpenSSL", targets: ["OpenSSL"])
    )
#endif
