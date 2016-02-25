import PackageDescription

let package = Package(
    name: "Vapor",
    exclude: [],
    targets: [
        Target(
            name: "Vapor",
            dependencies: []
        ),
        Target(
            name: "VaporExample",
            dependencies: [
                .Target(name: "Vapor")
            ]
        )
    ]
)
