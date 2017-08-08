import PackageDescription

let package = Package(
    name: "Vapor",
    targets: [
        // Framework
        Target(name: "Vapor", dependencies: [
            "Cache",
            "Sessions",
            "Configs"
        ]),

        // Misc
        Target(name: "Cache"),
        Target(name: "Sessions", dependencies: ["Cache"]),
        Target(name: "Configs"),
        Target(name: "Testing", dependencies: ["Vapor"]),

        // Development and Testing
        // Target(name: "Development", dependencies: ["Vapor"]),
        // Target(name: "Performance", dependencies: ["Vapor"]),
    ],
    dependencies: [
        // Core vapor transport layer
        .Package(url: "https://github.com/vapor/engine.git", majorVersion: 2),

        // Console protocol and implementation for powering command line interface.
        .Package(url: "https://github.com/vapor/console.git", majorVersion: 2),

        // JSON enum wrapper around Foundation JSON
        .Package(url: "https://github.com/vapor/json.git", majorVersion: 2),

        // A type safe routing package including HTTP and TypeSafe routers.
        .Package(url: "https://github.com/vapor/routing.git", majorVersion: 2),

        // Parses `Content-Type: multipart` as defined in RFC 2046.
        .Package(url: "https://github.com/vapor/multipart.git", majorVersion: 2),

        // Swift implementation of the BCrypt password hashing function
        .Package(url: "https://github.com/vapor/bcrypt.git", majorVersion: 1),
    ],
    exclude: [
        "Sources/Development",
        "Sources/Performance",
        "Sources/TypeSafeGenerator"
    ]
)
