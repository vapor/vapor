import PackageDescription

let package = Package(
    name: "Vapor",
    dependencies: [
        .Package(url: "https://github.com/Zewo/String.git", majorVersion: 0),
        .Package(url: "https://github.com/Zewo/JSON.git", majorVersion: 0),
        .Package(url: "https://github.com/ketzusaka/Hummingbird", majorVersion: 1)
    ],
    exclude: [
        "Sources/VaporDev",
        "Sources/Generator",
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

//with the new swiftpm we have to force it to create a static lib so that we can use it
//from xcode. this will become unnecessary once official xcode+swiftpm support is done.
//watch progress: https://github.com/apple/swift-package-manager/compare/xcodeproj?expand=1

let lib = Product(name: "Vapor", type: .Library(.Dynamic), modules: "Vapor")
products.append(lib)
