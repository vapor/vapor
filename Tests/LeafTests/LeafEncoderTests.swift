import Async
import Dispatch
import Leaf
import Service
import XCTest

class LeafEncoderTests: XCTestCase {
    func testString() {
        let data = "hello"
        try XCTAssertEqual(LeafEncoder().encode(data), .string(data))
    }

    func testDouble() {
        let data: Double = 3.14
        try XCTAssertEqual(LeafEncoder().encode(data), .double(data))
    }

    func testDictionary() {
        let data: [String: String] = ["string": "hello", "foo": "3.14"]
        try XCTAssertEqual(LeafEncoder().encode(data), .dictionary([
            "string": .string("hello"),
            "foo": .string("3.14")
        ]))
    }

    func testNestedDictionary() {
        let data: [String: [String: String]] = [
            "a": ["string": "hello", "foo": "3.14"],
            "b": ["greeting": "hey", "foo": "3.15"]
        ]
        try XCTAssertEqual(LeafEncoder().encode(data), .dictionary([
        "a": .dictionary([
            "string": .string("hello"),
            "foo": .string("3.14")
            ]),
        "b": .dictionary([
            "greeting": .string("hey"),
            "foo": .string("3.15")
            ])
        ]))
    }

    func testArray() {
        let data: [String] = ["string", "hello", "foo", "3.14"]
        try XCTAssertEqual(LeafEncoder().encode(data), .array([
            .string("string"), .string("hello"), .string("foo"), .string("3.14")
        ]))
    }

    func testNestedArray() {
        let data: [[String]] = [["string"], ["hello", "foo"], ["3.14"]]
        try XCTAssertEqual(LeafEncoder().encode(data), .array([
            .array([.string("string")]), .array([.string("hello"), .string("foo")]), .array([.string("3.14")])
        ]))
    }

    func testEncodable() {
        struct Hello: Encodable { var hello = "hello" }
        try XCTAssertEqual(LeafEncoder().encode(Hello()), .dictionary([
            "hello": .string("hello"),
        ]))
    }

    func testComplexEncodable() {
        struct Test: Encodable {
            var string: String = "hello"
            var double: Double = 3.14
            var int: Int = 42
            var float: Float = -0.5
            var bool: Bool = true
            var fib: [Int] = [0, 1, 1, 2, 3, 5, 8, 13]
        }

        try XCTAssertEqual(LeafEncoder().encode(Test()), .dictionary([
            "string": .string("hello"),
            "double": .double(3.14),
            "int": .int(42),
            "float": .double(-0.5),
            "bool": .bool(true),
            "fib": .array([.int(0), .int(1), .int(1), .int(2), .int(3), .int(5), .int(8), .int(13)]),
        ]))
    }

    func testNestedEncodable() {
        final class Test: Encodable {
            var string: String = "hello"
            var double: Double = 3.14
            var int: Int = 42
            var float: Float = -0.5
            var bool: Bool = true
            var sub: Test?
            init(sub: Test? = nil) {
                self.sub = sub
            }
        }

        let sub = Test()
        try XCTAssertEqual(LeafEncoder().encode(Test(sub: sub)), .dictionary([
            "string": .string("hello"),
            "double": .double(3.14),
            "int": .int(42),
            "float": .double(-0.5),
            "bool": .bool(true),
            "sub": .dictionary([
                "string": .string("hello"),
                "double": .double(3.14),
                "int": .int(42),
                "float": .double(-0.5),
                "bool": .bool(true),
            ])
        ]))
    }

    static var allTests = [
        ("testString", testString),
        ("testDouble", testDouble),
        ("testDictionary", testDictionary),
        ("testNestedDictionary", testNestedDictionary),
        ("testNestedArray", testNestedArray),
        ("testEncodable", testEncodable),
        ("testComplexEncodable", testComplexEncodable),
        ("testNestedEncodable", testNestedEncodable),
    ]
}
