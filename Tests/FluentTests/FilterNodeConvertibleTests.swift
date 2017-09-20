import Node

import XCTest
@testable import Fluent

class FilterNodeConvertibleTestEntity: Entity {
    static let fullClassName = "FluentTests.FilterNodeConvertibleTestEntity"

    let storage = Storage()

    var string0 = "field0"
    var string1 = "field1"
    var int0 = 0
    var int1 = 1

    required init(row: Row) throws {
        string0 = try row.get("string0")
        string1 = try row.get("string1")
        int0 = try row.get("int0")
        int1 = try row.get("int1")
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set("id", self.id)
        try row.set("string0", string0)
        try row.set("string1", string1)
        try row.set("int0", int0)
        try row.set("int1", int1)
        return row
    }
}

class FilterNodeConvertibleTests: XCTestCase {

    static var allTests = [
        ("testCompare", testCompare),
        ("testSubset", testSubset),
        ("testCustomFromString", testCustomFromString)
    ]

    static func makeCompare() throws -> Node {
        var compare = Node([:])
        try compare.set("entity", FilterNodeConvertibleTestEntity.fullClassName)
        var method = Node([:])
        try method.set("type", "compare")
        try method.set("field", "string0")
        try method.set("comparison", "equals")
        try method.set("value", "string0")
        try compare.set("method", method)
        return compare
    }

    static func makeSubset() throws -> Node {
        var subset = Node([:])
        try subset.set("entity", FilterNodeConvertibleTestEntity.fullClassName)
        var method = Node([:])
        try method.set("type", "subset")
        try method.set("field", "string0")
        try method.set("scope", "in")
        try method.set("values", ["string0", "string1"])
        try subset.set("method", method)
        return subset
    }

    static func makeGroup() throws -> Node {
        var group = Node([:])
        try group.set("entity", FilterNodeConvertibleTestEntity.fullClassName)
        var method = Node([:])
        try method.set("type", "group")
        try method.set("relation", "and")
        try method.set("filters", [makeCompare(), makeSubset()])
        try group.set("method", method)
        return group
    }

    func testCompare() throws {
        let _compare = try FilterNodeConvertibleTests.makeCompare()
        let compare = try Filter(node: _compare)
        XCTAssert(try compare.makeNode(in: nil) == _compare)

        switch(compare.method) {
        case .compare(let field, let comparison, let value):
            XCTAssert(field == "string0")
            XCTAssert(comparison == .equals)
            XCTAssert(value.string == "string0")
        default:
            XCTFail()
        }
    }

    func testSubset() throws {
        let _subset = try FilterNodeConvertibleTests.makeSubset()
        let subset = try Filter(node: _subset)

        XCTAssert(try subset.makeNode(in: nil) == _subset)

        switch(subset.method) {
        case .subset(let field, let scope, let values):
            XCTAssert(field == "string0")
            XCTAssert(scope == .in)
            XCTAssert(values == ["string0", "string1"])
        default:
            XCTFail()
        }
    }

    func testGroup() throws {
        let _group = try FilterNodeConvertibleTests.makeGroup()
        let group = try Filter(node: _group)

        XCTAssert(try group.makeNode(in: nil) == _group)

        let _compare = try FilterNodeConvertibleTests.makeCompare()
        let _subset = try FilterNodeConvertibleTests.makeSubset()

        switch(group.method) {
        case .group(let relation, let filters):
            XCTAssert(relation == .and)
            XCTAssert(try filters.map { $0.wrapped! }.map { try $0.makeNode(in: nil) } == [_compare, _subset])
        default:
            XCTFail()
        }
    }

    func testCustomFromString() throws {
        XCTAssert(try Filter.Comparison.customFromString("custom(test)") == .custom("test"))
    }
}
