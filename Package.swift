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
            name: "VaporDev",
            dependencies: [
                .Target(name: "Vapor")
            ]
        )
    ]
)
