// swift-tools-version:6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "vapor",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "Vapor", targets: ["Vapor"]),
        .library(name: "VaporTesting", targets: ["VaporTesting"]),
    ],
    traits: [
        .trait(name: "WebSockets"),
        .trait(name: "TLS"),
        .trait(name: "bcrypt"),
        .trait(name: "HTTPClient"),
        .trait(name: "Multipart"),
        .trait(name: "MacroRouting"),
        .default(enabledTraits: [
            "WebSockets",
            "TLS",
            "bcrypt",
            "HTTPClient",
            "Multipart",
            "MacroRouting",
        ])
    ],
    dependencies: [
        // HTTP client library built on SwiftNIO
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.0"),

        // 💻 APIs for creating interactive CLI tools.
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.14.0"),

        // 🔑 Hashing (SHA2, HMAC), encryption (AES), public-key (RSA), and random data generation.
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.0.0"),

        // 🚍 High-performance trie-node router.
        .package(url: "https://github.com/vapor/routing-kit.git", from: "5.0.0-beta"),

        // Event-driven network application framework for high performance protocol servers & clients, non-blocking.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.82.0"),

        // Bindings to OpenSSL-compatible libraries for TLS support in SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.34.0"),

        // HTTP/2 support for SwiftNIO
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.28.0"),

        // Useful code around SwiftNIO.
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.24.0"),

        // Swift logging API
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),

        // Swift metrics API
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.5.0"),
        
        // Swift tracing API
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.1.0"),
        
        // Swift service context
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.0.0"),

        // Swift collection algorithms
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.0.0"),

        // WebSocket client library built on SwiftNIO
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.13.0"),

        // MultipartKit, Multipart encoding and decoding
        .package(url: "https://github.com/vapor/multipart-kit.git", from: "5.0.0-alpha.5"),

        // Low-level atomic operations
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.1.0"),

        // Service Lifecycle Management
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.6.3"),

        // Network IO on Apple platforms
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.20.0"),

        // Swift Types for HTTP Requests
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),

        // Collection algorithms
        .package(url: "https://github.com/apple/swift-collections", from: "1.2.1"),

        // X509 certificate types for the Swift ecosystem
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.14.0"),

        // Work with certificate encoding schemes
        .package(url: "https://github.com/apple/swift-asn1.git", from: "1.0.0"),

        // Swift syntax parsing and generation
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    ],
    targets: [
        // C helpers
        .target(name: "CVaporBcrypt"),

        .target(
            name: "HTTPServerNew",
            dependencies: [
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(
                    name: "NIOTransportServices",
                    package: "swift-nio-transport-services",
                    condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS])
                ),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOHTTPTypes", package: "swift-nio-extras"),
                .product(name: "NIOHTTPTypesHTTP1", package: "swift-nio-extras"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Collections", package: "swift-collections"),
            ],
            swiftSettings: swiftSettings
        ),

        // Vapor
        .target(
            name: "Vapor",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client", condition: .when(traits: ["HTTPClient"])),
                .target(name: "CVaporBcrypt", condition: .when(traits: ["bcrypt"])),
                .product(name: "ConsoleKit", package: "console-kit"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOHTTPCompression", package: "swift-nio-extras"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOHTTP2", package: "swift-nio-http2"),
                .product(name: "NIOSSL", package: "swift-nio-ssl", condition: .when(traits: ["TLS"])),
                .product(name: "NIOWebSocket", package: "swift-nio", condition: .when(traits: ["WebSockets"])),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "RoutingKit", package: "routing-kit"),
                .product(name: "WebSocketKit", package: "websocket-kit", condition: .when(traits: ["WebSockets"])),
                .product(name: "MultipartKit", package: "multipart-kit", condition: .when(traits: ["Multipart"])),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "_NIOFileSystem", package: "swift-nio"),
                .product(name: "_NIOFileSystemFoundationCompat", package: "swift-nio"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .target(name: "HTTPServerNew"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "SwiftASN1", package: "swift-asn1"),
            ],
            swiftSettings: swiftSettings
        ),

        .macro(
            name: "VaporMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax", condition: .when(traits: ["MacroRouting"])),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax", condition: .when(traits: ["MacroRouting"])),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax", condition: .when(traits: ["MacroRouting"])),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax", condition: .when(traits: ["MacroRouting"])),
            ],
            swiftSettings: swiftSettings
        ),

        .target(
            name: "VaporMacros",
            dependencies: [
                "VaporMacrosPlugin",
            ],
            swiftSettings: swiftSettings
        ),

        // Development
        .executableTarget(
            name: "Development",
            dependencies: [
                .target(name: "Vapor"),
                "VaporMacros",
            ],
            resources: [.copy("Resources")],
            swiftSettings: swiftSettings
        ),

        // Testing
        .target(
            name: "VaporTesting",
            dependencies: [
                .target(name: "Vapor"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "VaporTests",
            dependencies: [
                .product(name: "NIOTestUtils", package: "swift-nio"),
                .product(name: "SwiftASN1", package: "swift-asn1"),
                .target(name: "VaporTesting"),
                .target(name: "Vapor"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            resources: [
                .copy("Utilities/foo.txt"),
                .copy("Utilities/index.html"),
                .copy("Utilities/SubUtilities/"),
                .copy("Utilities/foo bar.html"),
                .copy("Utilities/test.env"),
                .copy("Utilities/my-secret-env-content"),
                .copy("Utilities/expired.crt"),
                .copy("Utilities/expired.key"),
                .copy("Utilities/long-test-file.txt"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "VaporMacroTests",
            dependencies: [
                "VaporMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
    //.enableUpcomingFeature("InternalImportsByDefault"),
    // .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    //.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
] }
