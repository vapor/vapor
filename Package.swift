import PackageDescription

let package = Package(
    name: "Vapor",
    dependencies: [
        .Package(url: "https://github.com/Zewo/String.git", majorVersion: 0),
        .Package(url: "https://github.com/Zewo/JSON.git", majorVersion: 0),
        .Package(url: "https://github.com/ketzusaka/Hummingbird", majorVersion: 1)
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
