import PackageDescription

let package = Package(
    name: "Vapor",
    dependencies: [
        .Package(url: "https://github.com/Zewo/String.git", majorVersion: 0, minor: 4),
        .Package(url: "https://github.com/Zewo/JSON.git", majorVersion: 0, minor: 4),
        .Package(url: "https://github.com/ketzusaka/Hummingbird", majorVersion: 1),
        .Package(url: "https://github.com/qutheory/vapor-console-output.git", majorVersion: 0),
    ],
    exclude: [
        "XcodeProject",
        "Release"
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
