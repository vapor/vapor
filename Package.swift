import PackageDescription

let beta = Version(2,0,0, prereleaseIdentifiers: ["beta"])

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
        .Package(url: "https://github.com/vapor/engine.git", beta),

        // Console protocol and implementation for powering command line interface.
        .Package(url: "https://github.com/vapor/console.git", beta),

        // JSON enum wrapper around Foundation JSON
        .Package(url: "https://github.com/vapor/json.git", beta),

        // A type safe routing package including HTTP and TypeSafe routers.
        .Package(url: "https://github.com/vapor/routing.git", beta),

        // Parses `Content-Type: multipart` as defined in RFC 2046.
        .Package(url: "https://github.com/vapor/multipart.git", beta),

        // Swift implementation of the BCrypt password hashing function
        .Package(url: "https://github.com/vapor/bcrypt.git", Version(1,0,0, prereleaseIdentifiers: ["beta"]))
    ],
    exclude: [
        "Sources/Development",
        "Sources/Performance",
        "Sources/TypeSafeGenerator"
    ]
)
