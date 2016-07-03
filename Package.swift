import PackageDescription

let package = Package(
    name: "Vapor",
        targets: [
        Target(
            name: "Vapor"
        ),
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
        Target(
            name: "Generator"
        )
    ],
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

        //Wrapper around pthreads
        .Package(url: "https://github.com/ketzusaka/Strand.git", majorVersion: 1, minor: 5),

        //Sockets, used by the built in HTTP server
        .Package(url: "https://github.com/czechboy0/Socks.git", majorVersion: 0, minor: 8),

        // Syntax for easily accessing values from generic data.
        .Package(url: "https://github.com/qutheory/polymorphic.git", majorVersion: 0, minor: 2),

        // libc
        .Package(url: "https://github.com/qutheory/libc.git", majorVersion: 0, minor: 1)
    ],
    exclude: [
        "XcodeProject",
        "Generator",
        "Development"
    ]
)
