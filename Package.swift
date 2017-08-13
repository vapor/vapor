// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Vapor",
    products: [
        .library(name: "Cache", targets: ["Cache"]),
        .library(name: "Session", targets: ["Session"]),
        .library(name: "Testing", targets: ["Testing"]),
        .library(name: "Vapor", targets: ["Vapor"]),
    ],
    dependencies: [
        // Swift implementation of the BCrypt password hashing function
        .package(url: "https://github.com/vapor/bcrypt.git", .branch("beta")),

        // Console protocol and implementation for powering command line interface.
        .package(url: "https://github.com/vapor/console.git", .branch("beta")),

        // Useful helpers and extensions
        .package(url: "https://github.com/vapor/core.git", .branch("beta")),

        // Cryptographic digests and ciphers
        .package(url: "https://github.com/vapor/crypto.git", .branch("beta")),

        // Core vapor transport layer
        .package(url: "https://github.com/vapor/engine.git", .branch("beta")),
        
        // Parses `Content-Type: multipart` as defined in RFC 2046.
        .package(url: "https://github.com/vapor/multipart.git", .branch("beta")),
        
        // A type safe routing package including HTTP and TypeSafe routers.
        .package(url: "https://github.com/vapor/routing.git", .branch("beta")),

        // Service container and configuration system.
        .package(url: "https://github.com/vapor/service.git", .branch("beta")),
    ],
    targets: [
        .target(name: "Cache", dependencies: ["Core", "Service"]),
        .testTarget(name: "CacheTests", dependencies: ["Cache"]),
        .target(name: "Development", dependencies: ["Vapor"]),
        .target(name: "Session", dependencies: ["Cache", "Cookies", "Core", "Crypto", "HTTP", "Service"]),
        .testTarget(name: "SessionTests", dependencies: ["Session"]),
        .target(name: "Testing", dependencies: ["Core", "HTTP", "Vapor"]),
        .testTarget(name: "TestingTests", dependencies: ["Testing"]),
        .target(name: "Vapor", dependencies: [
            "BCrypt", 
            "Cache",
            "Command",
            "Console",
            "Core",
            "FormData",
            "HTTP",
            "Multipart",
            "Routing",
            "Service",
            "Session", 
            "SMTP",
            "WebSockets"
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)
