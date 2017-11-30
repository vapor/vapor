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
        .library(name: "Bits", targets: ["Bits"]),
        .library(name: "Core", targets: ["Core"]),
        .library(name: "libc", targets: ["libc"]),

        // Console
        .library(name: "Console", targets: ["Console"]),
        .library(name: "Command", targets: ["Command"]),

        // Crypto
        .library(name: "Crypto", targets: ["Crypto"]),

        // Debugging
        .library(name: "Debugging", targets: ["Debugging"]),

        // Fluent
        .library(name: "Fluent", targets: ["Fluent"]),
        .library(name: "FluentSQLite", targets: ["FluentSQLite"]),

        // FormURLEncoded
        .library(name: "FormURLEncoded", targets: ["Bits"]),

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

        // Redis
        .library(name: "Redis", targets: ["Redis"]),

        // Routing
        .library(name: "Routing", targets: ["Routing"]),

        // Service
        .library(name: "Service", targets: ["Service"]),

        // SQL
        .library(name: "SQL", targets: ["SQL"]),

        // SQLite
        .library(name: "SQLite", targets: ["SQLite"]),
        
        // TLS/SSL
        .library(name: "TLS", targets: ["TLS"]),

        // Vapor
        .library(name: "Vapor", targets: ["Vapor"]),
        
        // WebSockets
        .library(name: "WebSocket", targets: ["WebSocket"]),
    ],
    dependencies: [
        // Swift Promises, Futures, and Streams.
        .package(url: "https://github.com/vapor/async", .branch("master")),
    ],
    targets: [
        // Bits
        .target(name: "Bits"),

        // Boilerplate
        .target(name: "Boilerplate", dependencies: ["Fluent", "Service", "Routing", "Vapor"]),
        .target(name: "BoilerplateRun", dependencies: ["Boilerplate"]),

        // Core
        .target(name: "Core", dependencies: ["Async", "libc", "Debugging"]),
        .target(name: "libc"),
        

        // Console
        .target(name: "Console", dependencies: ["Async", "Core"]),
        .target(name: "Command", dependencies: ["Console"]),
        .testTarget(name: "ConsoleTests", dependencies: ["Console"]),
        .testTarget(name: "CommandTests", dependencies: ["Command"]),
        .target(name: "ConsoleExample", dependencies: ["Console"]),

        // Crypto
        .target(name: "Crypto", dependencies: ["libc", "Async", "Bits", "Core", "Debugging"]),
        .testTarget(name: "CryptoTests", dependencies: ["Crypto"]),

        // Debugging
        .target(name: "Debugging"),
        .testTarget(name: "DebuggingTests", dependencies: ["Debugging"]),

        // Fluent
        .target(name: "Fluent", dependencies: ["Async", "Core", "Service"]),
        .target(name: "FluentBenchmark", dependencies: ["Fluent"]),
        .target(name: "FluentSQL", dependencies: ["Fluent", "SQL"]),
        .target(name: "FluentSQLite", dependencies: ["Fluent", "FluentSQL", "SQLite"]),

        .testTarget(name: "FluentTests", dependencies: ["FluentBenchmark", "FluentSQLite", "SQLite"]),

        // FormURLEncoded
        .target(name: "FormURLEncoded", dependencies: ["Bits", "Debugging"]),
        .testTarget(name: "FormURLEncodedTests", dependencies: ["FormURLEncoded"]),

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
        .target(name: "HTTP", dependencies: ["CHTTP", "Service", "TCP"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "TCP", dependencies: ["Async", "Debugging", "libc"]),
        .testTarget(name: "TCPTests", dependencies: ["TCP"]),
        
        // HTTP/2
        .target(name: "HTTP2", dependencies: ["HTTP", "TLS", "Pufferfish"]),
        .testTarget(name: "HTTP2Tests", dependencies: ["HTTP2"]),

        // Random crypto
        .target(name: "Random", dependencies: ["Core"]),
        .testTarget(name: "RandomTests", dependencies: ["Random"]),
        
        // Compression
        .target(name: "Pufferfish"),
        .testTarget(name: "PufferfishTests", dependencies: ["Pufferfish"]),

        // Routing
        .target(name: "Routing", dependencies: ["Core", "Debugging", "HTTP", "WebSocket"]),
        .testTarget(name: "RoutingTests", dependencies: ["Routing"]),
        
        // Redis
        .target(name: "Redis", dependencies: ["Async", "Bits", "Debugging", "TCP"]),
        .testTarget(name: "RedisTests", dependencies: ["Redis"]),

        // Service
        .target(name: "Service", dependencies: ["Core", "Debugging"]),
        .testTarget(name: "ServiceTests", dependencies: ["Service"]),
        
        // Security
        .target(name: "ServerSecurity", dependencies: ["TCP", "libc"]),
       
        // TLS
        .target(name: "TLS", dependencies: ["Core", ssl, "TCP"]),
        .testTarget(name: "TLSTests", dependencies: ["TLS"]),

        // SQL
        .target(name: "SQL"),
        .testTarget(name: "SQLTests", dependencies: ["SQL"]),

        // SQLite
        .target(name: "CSQLite"),
        .target(name: "SQLite", dependencies: ["Core", "CSQLite", "Debugging", "Random"]),
        .testTarget(name: "SQLiteTests", dependencies: ["SQLite"]),

        // Vapor
        .target(name: "Development", dependencies: ["Fluent", "FluentSQLite", "Leaf", "Vapor", "MySQL", "SQLite"]),
        .target(name: "Vapor", dependencies: [
            "Command",
            "Console",
            "Core",
            "Debugging",
            "FormURLEncoded",
            "HTTP",
            "Leaf",
            "Routing",
            "Service",
            "TCP",
            "TLS",
            "ServerSecurity",
            "WebSocket",
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),

        // WebSocket
        .target(name: "WebSocket", dependencies: ["Core", "Debugging", "TCP", "TLS", "HTTP", "Crypto"]),
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
        .package(url: "https://github.com/vapor/copenssl.git", .exact("1.0.0-alpha.1"))
    )
    
    package.targets.append(
        .target(name: "OpenSSL", dependencies: ["COpenSSL", "Async", "Debugging"])
    )
    
    package.products.append(
        .library(name: "OpenSSL", targets: ["OpenSSL"])
    )
#endif
