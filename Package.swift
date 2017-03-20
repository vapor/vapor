import PackageDescription

let package = Package(
    name: "Vapor",
    targets: [
        // Framework
        Target(name: "Vapor", dependencies: [
            "Cache",
            "Sessions",
            "Settings"
        ]),

        // Misc
        Target(name: "Cache"),
        Target(name: "Sessions", dependencies: ["Cache"]),
        Target(name: "Settings"),
        Target(name: "Testing", dependencies: ["Vapor"]),

        // Development and Testing
        // Target(name: "Development", dependencies: ["Vapor"]),
        // Target(name: "Performance", dependencies: ["Vapor"]),
    ],
    dependencies: [
        // Core vapor transport layer
        .Package(url: "https://github.com/vapor/engine.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"])),

        // Console protocol and implementation for powering command line interface.
        .Package(url: "https://github.com/vapor/console.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"])),

        // JSON enum wrapper around Foundation JSON
        .Package(url: "https://github.com/vapor/json.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"])),

        // A type safe routing package including HTTP and TypeSafe routers.
        .Package(url: "https://github.com/vapor/routing.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"])),

        // Parses `Content-Type: multipart` as defined in RFC 2046.
        .Package(url: "https://github.com/vapor/multipart.git", Version(2,0,0, prereleaseIdentifiers: ["alpha"])),

        // Swift implementation of the BCrypt password hashing function
        .Package(url: "https://github.com/vapor/bcrypt.git", majorVersion: 0)
    ],
    exclude: [
        "Sources/Development",
        "Sources/Performance",
        "Sources/TypeSafeGenerator"
    ]
)
