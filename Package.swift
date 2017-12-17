// swift-tools-version:4.0
import PackageDescription

#if os(macOS) || os(iOS)
    let ssl: Target.Dependency = "AppleTLS"
#else
    let ssl: Target.Dependency = "OpenSSL"
#endif

let package = Package(
    name: "Vapor",
    products: [
        // Auth
        .library(name: "Authentication", targets: ["Authentication"]),

        // Core
        .library(name: "Bits", targets: ["Bits"]),
        .library(name: "JunkDrawer", targets: ["JunkDrawer"]),
        .library(name: "COperatingSystem", targets: ["COperatingSystem"]),

        // Console
        .library(name: "Console", targets: ["Console"]),
        .library(name: "Command", targets: ["Command"]),

        // Crypto
        .library(name: "Crypto", targets: ["Crypto"]),

        // Debugging
        .library(name: "Debugging", targets: ["Debugging"]),

        // Fluent
        .library(name: "Fluent", targets: ["Fluent"]),
//        .library(name: "FluentMySQL", targets: ["FluentMySQL"]),
        .library(name: "FluentSQLite", targets: ["FluentSQLite"]),

        // FormURLEncoded
        .library(name: "FormURLEncoded", targets: ["FormURLEncoded"]),

        // JWT
        .library(name: "JWT", targets: ["JWT"]),

        // Leaf
        .library(name: "Leaf", targets: ["Leaf"]),

        // Logging
        .library(name: "Logging", targets: ["Logging"]),

        // MySQL
        .library(name: "MySQL", targets: ["MySQL"]),
        
        // Multipart
        .library(name: "Multipart", targets: ["Multipart"]),

        // Net
        .library(name: "HTTP", targets: ["HTTP"]),
        // .library(name: "HTTP2", targets: ["HTTP2"]),
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

        // Validation
        .library(name: "Validation", targets: ["Validation"]),

        // Vapor
        .library(name: "Vapor", targets: ["Vapor"]),
        
        // WebSockets
         .library(name: "WebSocket", targets: ["WebSocket"]),
    ],
    dependencies: [
        // Swift Promises, Futures, and Streams.
        .package(url: "https://github.com/vapor/async.git", .branch("protocol-streams")),
    ],
    targets: [
        .target(name: "Authentication", dependencies: [
            "Async", "Bits", "Crypto", "Debugging", "Fluent", "HTTP", "Service", "Vapor"
        ]),
        .testTarget(name: "AuthenticationTests", dependencies: [
            "Authentication", "FluentSQLite", "Vapor"
        ]),

        // Bits
        .target(name: "Bits"),

        // Boilerplate
        .target(name: "Boilerplate", dependencies: ["Fluent", "Service", "Routing", "Vapor"]),
        .target(name: "BoilerplateRun", dependencies: ["Boilerplate"]),

        // Core
        .target(name: "JunkDrawer", dependencies: ["Async", "Bits", "COperatingSystem", "Debugging"]),
        .testTarget(name: "JunkDrawerTests", dependencies: ["JunkDrawer"]),
        .target(name: "COperatingSystem"),
        

        // Console
        .target(name: "Console", dependencies: ["Async", "JunkDrawer"]),
        .target(name: "Command", dependencies: ["Console"]),
        .testTarget(name: "ConsoleTests", dependencies: ["Console"]),
        .testTarget(name: "CommandTests", dependencies: ["Command"]),
        .target(name: "ConsoleExample", dependencies: ["Console"]),

        // Crypto
        .target(name: "Crypto", dependencies: ["Async", "Bits", "COperatingSystem", "Debugging", "JunkDrawer"]),
        .testTarget(name: "CryptoTests", dependencies: ["Crypto"]),

        // Debugging
        .target(name: "Debugging"),
        .testTarget(name: "DebuggingTests", dependencies: ["Debugging"]),

        // Fluent
        .target(name: "Fluent", dependencies: ["Async", "JunkDrawer", "Service"]),
        .target(name: "FluentBenchmark", dependencies: ["Fluent"]),
        .target(name: "FluentSQL", dependencies: ["Fluent", "SQL"]),
        .target(name: "FluentSQLite", dependencies: ["Fluent", "FluentSQL", "SQLite"]),
//         .target(name: "FluentMySQL", dependencies: ["Fluent", "FluentSQL", "MySQL"]),
//         .testTarget(name: "FluentMySQLTests", dependencies: ["FluentMySQL"]),

        .testTarget(name: "FluentTests", dependencies: ["FluentBenchmark", "FluentSQLite", "SQLite"]),

        // FormURLEncoded
        .target(name: "FormURLEncoded", dependencies: ["Bits", "HTTP", "Debugging"]),
        .testTarget(name: "FormURLEncodedTests", dependencies: ["FormURLEncoded"]),

        // JWT
        .target(name: "JWT", dependencies: ["Crypto"]),
        .testTarget(name: "JWTTests", dependencies: ["JWT"]),

        // Leaf
        .target(name: "Leaf", dependencies: ["JunkDrawer", "Service"]),
        .testTarget(name: "LeafTests", dependencies: ["Leaf"]),

        // Logging
        .target(name: "Logging", dependencies: ["JunkDrawer", "Service"]),
        .testTarget(name: "LoggingTests", dependencies: ["Logging"]),

        // MySQL
        .target(name: "MySQL", dependencies: ["TCP", /*"TLS",*/ "Crypto"]),
        .testTarget(name: "MySQLTests", dependencies: ["MySQL"]),
        
        // Multipart
        .target(name: "Multipart", dependencies: ["JunkDrawer", "Debugging", "HTTP"]),
        .testTarget(name: "MultipartTests", dependencies: ["Multipart"]),

        // Net
        .target(name: "CHTTP"),
        .target(name: "HTTP", dependencies: ["CHTTP", "TCP"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "TCP", dependencies: ["Async", "COperatingSystem", "Debugging", "Service"]),
        .testTarget(name: "TCPTests", dependencies: ["TCP"]),
        
        // HTTP/2
        // .target(name: "HTTP2", dependencies: ["HTTP", "TLS", "Pufferfish"]),
        // .testTarget(name: "HTTP2Tests", dependencies: ["HTTP2"]),

        // Random crypto
        .target(name: "Random", dependencies: ["JunkDrawer"]),
        .testTarget(name: "RandomTests", dependencies: ["Random"]),
        
        // Compression
        .target(name: "Pufferfish"),
        .testTarget(name: "PufferfishTests", dependencies: ["Pufferfish"]),

        // Routing
        .target(name: "Routing", dependencies: ["JunkDrawer", "Debugging", "HTTP", /*"WebSocket"*/]),
        .testTarget(name: "RoutingTests", dependencies: ["Routing"]),
        
        // Redis
        .target(name: "Redis", dependencies: ["Async", "Bits", "Debugging", "TCP"]),
        .testTarget(name: "RedisTests", dependencies: ["Redis"]),

        // Service
        .target(name: "Service", dependencies: ["JunkDrawer", "Debugging"]),
        .testTarget(name: "ServiceTests", dependencies: ["Service"]),
        
        // Security
        .target(name: "ServerSecurity", dependencies: ["COperatingSystem", "TCP"]),
       
        // TLS
        .target(name: "TLS", dependencies: ["Async", "Bits", "Debugging", "TCP"]),
        .testTarget(name: "TLSTests", dependencies: ["OpenSSL", "TLS"]),

        // SQL
        .target(name: "SQL"),
        .testTarget(name: "SQLTests", dependencies: ["SQL"]),

        // SQLite
        .target(name: "CSQLite"),
        .target(name: "SQLite", dependencies: ["JunkDrawer", "CSQLite", "Debugging", "Random"]),
        .testTarget(name: "SQLiteTests", dependencies: ["SQLite"]),

        // Validation
        .target(name: "Validation", dependencies: ["JunkDrawer"]),
        .testTarget(name: "ValidationTests", dependencies: ["Validation"]),

        // Vapor
        .target(name: "Development", dependencies: ["Fluent", "FluentSQLite", "Leaf", "Vapor", "SQLite"]),
        .target(name: "Vapor", dependencies: [
            "Command",
            "Console",
            "COperatingSystem",
            "Debugging",
            "FormURLEncoded",
            "HTTP",
            "JunkDrawer",
            "Leaf",
            "Logging",
            "Multipart",
            "Routing",
            "Service",
            "TCP",
            "TLS",
            "ServerSecurity",
            // ssl,
            "AppleTLS",
            "OpenSSL"
            // "WebSocket",
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),

        // WebSocket
         .target(name: "WebSocket", dependencies: ["JunkDrawer", "Debugging", "TCP", /*"TLS",*/ "HTTP", "Crypto"]),
         .testTarget(name: "WebSocketTests", dependencies: ["WebSocket"]),
    ]
)

//#if os(macOS) || os(iOS)
   package.targets.append(
        .target(name: "AppleTLS", dependencies: ["Async", "Bits", "Debugging", "TLS"])
    )

    package.products.append(
        .library(name: "AppleTLS", targets: ["AppleTLS"])
    )
//#else
    package.dependencies.append(
        .package(url: "https://github.com/vapor/copenssl.git", .exact("1.0.0-alpha.1"))
    )
    
    package.targets.append(
        .target(name: "OpenSSL", dependencies: ["Async", "COpenSSL", "Debugging", "TLS"])
    )
//#endif

