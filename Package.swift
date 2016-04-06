import PackageDescription

let package = Package(
    name: "Vapor",
    dependencies: [
        .Package(url: "https://github.com/Zewo/String.git", majorVersion: 0, minor: 4),
        .Package(url: "https://github.com/Zewo/JSON.git", majorVersion: 0, minor: 4),
        .Package(url: "https://github.com/ketzusaka/Hummingbird.git", majorVersion: 1, minor: 1),
        .Package(url: "https://github.com/swiftx/s4.git", majorVersion: 0, minor: 2),
        .Package(url: "https://github.com/qutheory/HMAC.git", majorVersion: 0, minor: 2),
        .Package(url: "https://github.com/qutheory/vapor-console-output.git", majorVersion: 0),
    ],
    exclude: [
        "XcodeProject",
    ],
    targets: [
        Target(
            name: "Vapor",
            dependencies: [
                .Target(name: "libc")
            ]
        ),
        Target(
            name: "VaporDev",
            dependencies: [
                .Target(name: "Vapor")
            ]
        )
    ]
)
