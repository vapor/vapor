import XCTest
@testable import Fluent

class RowTests: XCTestCase {
    static let allTests = [
        ("testFuzzyRowArray", testFuzzyRowArray),
    ]
    
    func testFuzzyRowArray() throws {
        Node.fuzzy.append(Row.self)

        class Foo: RowConvertible {
            let name: String
            init(name: String) {
                self.name = name
            }
            required init(row: Row) throws {
                name = try row.get("name")
            }

            func makeRow() throws -> Row {
                var row = Row()
                try row.set("name", name)
                return row
            }
        }

        let foos = [Foo(name: "A"), Foo(name: "B")]
        let row = try Row(node: foos)
        XCTAssertEqual(row, [["name": "A"], ["name": "B"]])
    }
}
