import PackageDescription

let package = Package(
    name: "Vapor",
    targets: [
        // Framework
        Target(name: "Vapor", dependencies: [
            "Routing",
            "HTTPRouting",
            "TypeSafeRouting",
            "Auth",
            "Cache",
            "Cookies",
            "Sessions",
            "Settings"
        ]),

        // Routing
        Target(name: "Routing"),
        Target(name: "HTTPRouting", dependencies: ["Routing"]),

        // Type Safe
        Target(name: "TypeSafeRouting", dependencies: ["Routing", "HTTPRouting"]),
        // Target(name: "TypeSafeGenerator"),

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
        .Package(url: "https://github.com/vapor/crypto.git", majorVersion: 0, minor: 3),

        // ORM for interacting with databases
        .Package(url: "https://github.com/vapor/fluent.git", majorVersion: 0, minor: 11),

        // Core vapor transport layer
        .Package(url: "https://github.com/vapor/engine.git", majorVersion: 0, minor: 8),

        // Console protocol and implementation for powering command line interface.
        .Package(url: "https://github.com/vapor/console.git", majorVersion: 0, minor: 7),

        // JSON enum wrapper around Foundation JSON
        .Package(url: "https://github.com/vapor/json.git", majorVersion: 0, minor: 7),

        // A security framework for Swift.
        .Package(url: "https://github.com/stormpath/Turnstile.git", majorVersion: 0, minor: 4),

        // An extensible templating language built for Vapor. 🍃
        .Package(url: "https://github.com/vapor/leaf.git", majorVersion: 0, minor: 2)
    ],
    exclude: [
        "Sources/Development",
        "Sources/Performance",
        "Sources/TypeSafeGenerator"
    ]
)
