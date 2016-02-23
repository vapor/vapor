import PackageDescription

let package = Package(
    name: "Vapor",
    dependencies: [
        .Package(url: "https://github.com/gfx/Swift-PureJsonSerializer.git", majorVersion: 1),
        .Package(url: "https://github.com/qutheory/crypto.git", majorVersion: 0),
    ]
)
