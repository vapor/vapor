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
            "Config",
            "Cookies"
        ]),

        // Routing
        Target(name: "Routing"),
        Target(name: "HTTPRouting", dependencies: ["Routing"]),

        // Type Safe
        Target(name: "TypeSafeRouting", dependencies: ["Routing", "HTTPRouting"]),
        Target(name: "TypeSafeGenerator"),

        // Misc
        Target(name: "Auth", dependencies: ["Middleware", "Cookies"]),
        Target(name: "Cache"),
        Target(name: "Config"),
        Target(name: "Cookies"),
        Target(name: "Middleware"),

        // Development and Testing
        Target(name: "Development", dependencies: ["Vapor"]),
        Target(name: "Performance", dependencies: ["Vapor"]),
    ],
    dependencies: [
        // SHA2 + HMAC hashing. Used by the core to create session identifiers.
        .Package(url: "https://github.com/vapor/crypto.git", majorVersion: 0, minor: 2),

        // ORM for interacting with databases
        .Package(url: "https://github.com/vapor/fluent.git", majorVersion: 0, minor: 10),

        // Core vapor transport layer
        .Package(url: "https://github.com/vapor/engine.git", majorVersion: 0, minor: 6),

        // Console protocol and implementation for powering command line interface.
        .Package(url: "https://github.com/vapor/console.git", majorVersion: 0, minor: 6),

        // JSON enum wrapper around Foundation JSON
        .Package(url: "https://github.com/vapor/json.git", majorVersion: 0, minor: 5),

        // A security framework for Swift.
        .Package(url: "https://github.com/stormpath/Turnstile.git", majorVersion: 0, minor: 3),

		// An extensible templating language built for Vapor. 🍃
		.Package(url: "https://github.com/vapor/leaf.git", majorVersion: 0, minor: 1)
    ],
    exclude: [
        // No excludes currently
    ]
)
