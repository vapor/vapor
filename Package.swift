import PackageDescription

var exclude: [String] = []
#if os(Linux)
exclude.append("Sources/Generator")
#endif

var targets: [Target] = [
    Target(
        name: "Development",
        dependencies: [
            .Target(name: "Vapor")
        ]
    ),
    Target(
        name: "Performance",
        dependencies: [
            .Target(name: "Vapor")
        ]
    ),
]
#if !os(Linux)
targets += [
  Target(
      name: "Generator"
  )
]
#endif

let package = Package(
    name: "Vapor",
    targets: targets,
    dependencies: [
        //Standards package. Contains protocols for cross-project compatability.
        .Package(url: "https://github.com/open-swift/S4.git", majorVersion: 0, minor: 10),

        //Parses and serializes JSON - using fork until update core library
        .Package(url: "https://github.com/czechboy0/Jay.git", majorVersion: 0, minor: 12),

        //SHA2 + HMAC hashing. Used by the core to create session identifiers.
        .Package(url: "https://github.com/CryptoKitten/HMAC.git", majorVersion: 0, minor: 8),
        .Package(url: "https://github.com/CryptoKitten/SHA2.git", majorVersion: 0, minor: 8),

        //Websockets
        .Package(url: "https://github.com/CryptoKitten/SHA1.git", majorVersion: 0, minor: 8),

        //ORM for interacting with databases
        .Package(url: "https://github.com/qutheory/fluent.git", majorVersion: 0, minor: 7),

        //Allows complex key path subscripts
        .Package(url: "https://github.com/qutheory/path-indexable.git", majorVersion: 0, minor: 2),
        
        // Syntax for easily accessing values from generic data.
        .Package(url: "https://github.com/qutheory/polymorphic.git", majorVersion: 0, minor: 2),

        //Core vapor transport layer
        .Package(url: "https://github.com/qutheory/engine.git", majorVersion: 0, minor: 1),

        // Console protocol and implementation for powering command line interface.
        .Package(url: "https://github.com/qutheory/console.git", majorVersion: 0, minor: 2)
    ],
    exclude: exclude
)
