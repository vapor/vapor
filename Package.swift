import PackageDescription

let package = Package(
    name: "Vapor",
    dependencies: [
        .Package(url: "https://github.com/tannernelson/swifter.git", majorVersion: 1),
    ]
)

