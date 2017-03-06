import XCTest
import Node
@testable import Settings

class ConfigTests: XCTestCase {
    static let allTests = [
        ("testLoad", testLoad),
        ("testExample", testExample),
        ("testEmpty", testEmpty),
        ("testConversions", testConversions),
    ]
    
    func testLoad() throws {
        let config = try Config(
            prioritized: [
                .directory(root: configDir.finished(with: "/") + "inner"),
                .directory(root: configDir)
            ]
        )
        let expectation: Node = [
            "test": [
                "name": "inner/test"
            ],
            "file": ["hello": .bytes("Hello!\n".makeBytes())]
        ]
        XCTAssertEqual(config, Config(expectation))
    }

    func testExample() throws {
        let config = try Config(
            prioritized: [
                .memory(name: "app", config: ["port": 8080]),
                .commandLine
            ]
        )

        let expectation: Node = [
            "app": [
                "port": 8080
            ]
        ]
        XCTAssertEqual(config, Config(expectation))
    }

    func testEmpty() throws {
        let config = try Config(
            prioritized: [
                .directory(root: "i/dont/exist")
            ]
        )
        XCTAssertEqual(config, Config([:]))
    }

    func testConversions() throws {
        let node: Node = [
            "name": "World"
        ]

        let config: Config = node.converted()
        let back: Node = config.converted()
        XCTAssertEqual(node, back)
    }
}
