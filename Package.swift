// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Vapor",
    products: [
        // Core
        .library(name: "Core", targets: ["Core"]),
        .library(name: "libc", targets: ["libc"]),

        // Crypto
        .library(name: "Crypto", targets: ["Crypto"]),

        // Debugging
        .library(name: "Debugging", targets: ["Debugging"]),

        // Leaf
        .library(name: "Leaf", targets: ["Leaf"]),

        // MySQL
        .library(name: "MySQL", targets: ["MySQL"]),

        // Net
        .library(name: "HTTP", targets: ["HTTP"]),
        .library(name: "TCP", targets: ["TCP"]),
        
        // WebSockets
        .library(name: "WebSocket", targets: ["WebSocket"]),

        // Routing
        .library(name: "Routing", targets: ["Routing"]),

        // Service
        .library(name: "Service", targets: ["Service"]),

        // Vapor
        .library(name: "Vapor", targets: ["Vapor"]),
    ],
    dependencies: [],
    targets: [
        // Async
        .target(name: "Async", dependencies: ["Debugging"]),
        .testTarget(name: "AsyncTests", dependencies: ["Async"]),
        
        // Bits
        .target(name: "Bits"),
        .testTarget(name: "BitsTests", dependencies: ["Bits"]),
        
        // Core
        .target(name: "Core", dependencies: ["libc", "Debugging", "Async"]),
//        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .target(name: "libc"),

        // Crypto
        .target(name: "Crypto", dependencies: ["Core"]),
        .testTarget(name: "CryptoTests", dependencies: ["Crypto"]),

        // Debugging
        .target(name: "Debugging"),
        .testTarget(name: "DebuggingTests", dependencies: ["Debugging"]),
        
        // Files
        .target(name: "Files", dependencies: ["libc", "Core"]),
        .testTarget(name: "FilesTests", dependencies: ["Files"]),
        
        // HTTP
        .target(name: "CHTTP"),
        .target(name: "HTTP", dependencies: ["CHTTP", "TCP", "Files", "Web"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),

        // Leaf
        .target(name: "Leaf", dependencies: ["Core", "Service", "Files"]),
        .testTarget(name: "LeafTests", dependencies: ["Leaf"]),
        
        // MySQL
        .target(name: "MySQL", dependencies: ["TCP", "Crypto"]),
        .testTarget(name: "MySQLTests", dependencies: ["MySQL"]),
        
        // Network
        .target(name: "TCP", dependencies: ["Debugging", "Async", "Bits", "libc"]),
        .testTarget(name: "TCPTests", dependencies: ["TCP"]),
        
        // Web
        .target(name: "Web", dependencies: ["Files"]),
        .testTarget(name: "WebTests", dependencies: ["Web"]),
        
        // WebSocket
        .target(name: "WebSocket", dependencies: ["Core", "Debugging", "TCP", "HTTP", "Crypto"]),
        .testTarget(name: "WebSocketTests", dependencies: ["WebSocket"]),

        // Routing
        .target(name: "Routing", dependencies: ["Core", "Debugging", "HTTP", "WebSocket"]),
        .testTarget(name: "RoutingTests", dependencies: ["Routing"]),

        // Service
        .target(name: "Service", dependencies: ["Core", "Debugging"]),
        .testTarget(name: "ServiceTests", dependencies: ["Service"]),

        // Vapor
        .target(name: "Development", dependencies: ["Leaf", "Vapor", "MySQL"]),
        .target(name: "Vapor", dependencies: [
            "Core",
            "Debugging",
            "HTTP",
            "Leaf",
            "Routing",
            "Service",
            "TCP",
            "WebSocket",
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)
