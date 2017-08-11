// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Vapor",
    products: [
        .library(name: "Cache", targets: ["Cache"]),
        .library(name: "Session", targets: ["Session"]),
        .library(name: "Testing", targets: ["Testing"]),
        .library(name: "URLEncoded", targets: ["URLEncoded"]),
        .library(name: "Vapor", targets: ["Vapor"]),
    ],
    dependencies: [
        // Swift implementation of the BCrypt password hashing function
        .package(url: "https://github.com/vapor/bcrypt.git", .upToNextMajor(from: "1.1.0")),

        // Console protocol and implementation for powering command line interface.
        .package(url: "https://github.com/vapor/console.git", .branch("beta")),

        // Useful helpers and extensions
        .package(url: "https://github.com/vapor/core.git", .upToNextMajor(from: "2.1.2")),

        // Cryptographic digests and ciphers
        .package(url: "https://github.com/vapor/crypto.git", .upToNextMajor(from: "2.1.0")),

        // Core vapor transport layer
        .package(url: "https://github.com/vapor/engine.git", .branch("beta")),

        // JSON enum wrapper around Foundation JSON
        .package(url: "https://github.com/vapor/json.git", .branch("mapper")),

        // Data mapper
        .package(url: "https://github.com/vapor/mapper.git", .branch("beta")),

        // FIXME
        .package(url: "https://github.com/vapor/node.git", .branch("master")),
        
        // Parses `Content-Type: multipart` as defined in RFC 2046.
        .package(url: "https://github.com/vapor/multipart.git", .upToNextMajor(from: "2.1.0")),
        
        // A type safe routing package including HTTP and TypeSafe routers.
        .package(url: "https://github.com/vapor/routing.git", .upToNextMajor(from: "2.1.0")),

        // Service container and configuration system.
        .package(url: "https://github.com/vapor/service.git", .branch("beta")),
    ],
    targets: [
        .target(name: "Cache", dependencies: ["Mapper", "Service"]),
        .testTarget(name: "CacheTests", dependencies: ["Cache"]),
        .target(name: "URLEncoded", dependencies: ["HTTP", "Mapper"]),
        .testTarget(name: "URLEncodedTests", dependencies: ["URLEncoded"]),
        .target(name: "Session", dependencies: ["Cache", "Cookies", "Crypto", "HTTP", "Service"]),
        .testTarget(name: "SessionTests", dependencies: ["Session"]),
        .target(name: "Testing", dependencies: ["Core", "HTTP", "Vapor"]),
        .testTarget(name: "TestingTests", dependencies: ["Testing"]),
        .target(name: "Vapor", dependencies: [
            "BCrypt", 
            "Cache", 
            "Console", 
            "FormData",
            "HTTP", 
            "JSONs",
            "Mapper",
            "Multipart",
            "Routing",
            "Service",
            "Session", 
            "SMTP",
            "URLEncoded",
            "WebSockets"
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)
