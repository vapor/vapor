import XCTest
import Node
@testable import Configs

var configDir: String {
    #if swift(>=4.0)
    let parent = #file.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
    #else
    let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
    #endif
    let path = "/\(parent)/../../Sources/Configs/TestFiles"
    return path
}

class MergeTests: XCTestCase {
    static let allTests = [
        ("testFile", testFile),
        ("testMerge", testMerge)
    ]
    
    func testFile() throws {
        let node = try Node.makeConfig(directory: configDir)
        let expectation: Node = [
            "test": [
                "name": "a"
            ],
            "file": ["hello": .bytes("Hello!\n".makeBytes())]
        ]
        XCTAssertEqual(node, expectation)
    }

    func testMerge() throws {
        let a: Node = [
            "name": "a"
        ]

        let b: Node = [
            "name": "b",
            "nest": [
                "key": "*"
            ]
        ]

        let c: Node = [
            "name": "c",
            "nest": [
                "key": "&",
                "additional": "here"
            ]
        ]

        let node = try Node.makeConfig(
            prioritized: [
                .memory(name: "app", config: a),
                .memory(name: "app", config: b),
                .memory(name: "app", config: c)
            ]
        )
        let expectation: Node = [
            "app": [
                "name": "a",
                "nest": [
                    "key": "*",
                    "additional": "here"
                ]
            ]
        ]
        XCTAssertEqual(node, expectation)
    }
}
