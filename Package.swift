import PackageDescription

var exclude: [String] = []
#if os(Linux)
exclude.append("Sources/Generator")
#endif

var targets = [
    Target(name: "Vapor", dependencies: ["Branches"]),
    Target(name: "Branches"),
    Target(name: "Development", dependencies: ["Vapor"]),
    Target(name: "Performance", dependencies: ["Vapor"])
]

let package = Package(
    name: "Vapor",
    targets: targets,
    dependencies: [
        //SHA2 + HMAC hashing. Used by the core to create session identifiers.
        .Package(url: "https://github.com/CryptoKitten/HMAC.git", majorVersion: 0, minor: 10),
        .Package(url: "https://github.com/CryptoKitten/SHA2.git", majorVersion: 0, minor: 9),

        //ORM for interacting with databases
        .Package(url: "https://github.com/qutheory/fluent.git", majorVersion: 0, minor: 8),

        //Core vapor transport layer
        .Package(url: "https://github.com/qutheory/engine.git", majorVersion: 0, minor: 3),

        //Console protocol and implementation for powering command line interface.
        .Package(url: "https://github.com/qutheory/console.git", majorVersion: 0, minor: 4),

        //JSON
        .Package(url: "https://github.com/qutheory/json.git", majorVersion: 0, minor: 2)
    ],
    exclude: exclude
)
