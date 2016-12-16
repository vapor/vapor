import PackageDescription

let package = Package(
    name: "Vapor",
    targets: [
        // Framework
        Target(name: "Vapor", dependencies: [
            "Auth",
            "Cache",
            "Cookies",
            "Sessions",
            "Settings"
        ]),

        // Misc
        Target(name: "Auth", dependencies: ["Cookies", "Cache"]),
        Target(name: "Cache"),
        Target(name: "Cookies"),
        Target(name: "Sessions", dependencies: ["Cookies"]),
        Target(name: "Settings"),

        // Development and Testing
        // Target(name: "Development", dependencies: ["Vapor"]),
        // Target(name: "Performance", dependencies: ["Vapor"]),
    ],
    dependencies: [
        // SHA2 + HMAC hashing. Used by the core to create session identifiers.
        .Package(url: "https://github.com/vapor/crypto.git", majorVersion: 1),

        // ORM for interacting with databases
        .Package(url: "https://github.com/vapor/fluent.git", majorVersion: 1),

        // Core vapor transport layer
        .Package(url: "https://github.com/vapor/engine.git", majorVersion: 1),

        // Console protocol and implementation for powering command line interface.
        .Package(url: "https://github.com/vapor/console.git", majorVersion: 1),

        // JSON enum wrapper around Foundation JSON
        .Package(url: "https://github.com/vapor/json.git", majorVersion: 1),

        // A security framework for Swift.
        .Package(url: "https://github.com/stormpath/Turnstile.git", majorVersion: 1),

        // An extensible templating language built for Vapor. 🍃
        .Package(url: "https://github.com/vapor/leaf.git", majorVersion: 1),

        // A type safe routing package including HTTP and TypeSafe routers.
        .Package(url: "https://github.com/vapor/routing.git", majorVersion: 1),
    ],
    exclude: [
        "Sources/Development",
        "Sources/Performance",
        "Sources/TypeSafeGenerator"
    ]
)
