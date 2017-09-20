import XCTest
@testable import Fluent

class GroupTests: XCTestCase {
    static var allTests = [
        ("testBasic", testBasic)
    ]

    var database: Database!
    override func setUp() {
        database = Database(DummyDriver())
    }

    func testBasic() throws {
        let query = Query<User>(database)
        try query.filter("1", "1").or { subquery in
            try subquery.filter("2", "2").filter("3", "3")
        }.filter("4", "4")

        XCTAssertEqual(query.filters.count, 3)
    }
}
