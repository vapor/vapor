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

        // Routing
        .library(name: "Routing", targets: ["Routing"]),

        // Service
        .library(name: "Service", targets: ["Service"]),

        // Vapor
        .library(name: "Vapor", targets: ["Vapor"]),
    ],
    dependencies: [],
    targets: [
        // Core
        .target(name: "Core", dependencies: ["libc", "Debugging"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .target(name: "libc"),

        // Crypto
        .target(name: "Crypto", dependencies: ["Core"]),
        .testTarget(name: "CryptoTests", dependencies: ["Crypto"]),

        // Debugging
        .target(name: "Debugging"),
        .testTarget(name: "DebuggingTests", dependencies: ["Debugging"]),

        // Leaf
        .target(name: "Leaf", dependencies: ["Core", "Service"]),
        .testTarget(name: "LeafTests", dependencies: ["Leaf"]),

        // MySQL

        .target(name: "MySQL", dependencies: ["TCP", "Crypto"]),
        .testTarget(name: "MySQLTests", dependencies: ["MySQL"]),

        // Net
        .target(name: "CHTTP"),
        .target(name: "HTTP", dependencies: ["CHTTP", "TCP"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"]),
        .target(name: "TCP", dependencies: ["Debugging", "Core", "libc"]),
        .testTarget(name: "TCPTests", dependencies: ["TCP"]),

        // Routing
        .target(name: "Routing", dependencies: ["Core", "Debugging", "HTTP"]),
        .testTarget(name: "RoutingTests", dependencies: ["Routing"]),

        // Service
        .target(name: "Service", dependencies: ["Core", "Debugging"]),
        .testTarget(name: "ServiceTests", dependencies: ["Service"]),

        // Vapor
        .target(name: "Development", dependencies: ["Leaf", "Vapor"]),
        .target(name: "Vapor", dependencies: [
            "Core",
            "Debugging",
            "HTTP",
            "Routing",
            "Service",
            "TCP",
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)
