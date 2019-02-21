// swift-tools-version:4.2
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
        // .package(url: "https://github.com/vapor/crypto.git", from: "3.0.0"),

        // 🚀 Non-blocking, event-driven HTTP for Swift built on Swift NIO.
        .package(url: "https://github.com/vapor/http.git", .branch("streaming-body")),

        // 🏞 Parses and serializes multipart-encoded data with Codable support.
        // .package(url: "https://github.com/vapor/multipart.git", from: "3.0.0"),

        // 🚍 High-performance trie-node router.
        .package(url: "https://github.com/vapor/routing.git", .branch("master")),

        // 📦 Dependency injection / inversion of control framework.
        .package(url: "https://github.com/vapor/service.git", .branch("master")),

        // 📝 Parses and serializes url-encoded form data with Codable support.
        // .package(url: "https://github.com/vapor/url-encoded-form.git", from: "1.0.0"),

        // ✅ Extensible data validation library (email, alphanumeric, UUID, etc)
        // .package(url: "https://github.com/vapor/validation.git", from: "2.0.0"),
    ],
    targets: [
        // Boilerplate
        .target(name: "Boilerplate", dependencies: ["Vapor"]),
        .target(name: "BoilerplateRun", dependencies: ["Boilerplate"]),

        // Vapor
        .target(name: "Development", dependencies: ["Vapor"]),
        .target(name: "Vapor", dependencies: [
            "ConsoleKit",
            // "Crypto",
            "HTTPKit",
            // "Multipart",
            "RoutingKit",
            "ServiceKit",
            // "URLEncodedForm",
            // "Validation",
        ]),
        .testTarget(name: "VaporTests", dependencies: ["Vapor"]),
    ]
)
