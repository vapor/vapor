import XCTest
@testable import Fluent

class QueryFiltersTests: XCTestCase {
    static var allTests = [
        ("testBasalQuery", testBasalQuery),
        ("testBasicQuery", testBasicQuery),
        ("testLikeQuery", testLikeQuery),
        ("testCountQuery", testCountQuery),
        ("testDeleteQuery", testDeleteQuery),
    ]

    override func setUp() {
        database = Database(DummyDriver())
        Database.default = database
    }

    var database: Database!

    func testBasalQuery() throws {
        let query = try DummyModel.makeQuery()

        XCTAssert(query.action == .fetch([]), "Default action should be fetch")
        XCTAssert(query.filters.count == 0, "Filters should be empty")
        XCTAssert(query.data.isEmpty == true, "Data should be empty")
        XCTAssert(query.limits.isEmpty == true, "Limit should be empty")
        XCTAssert(query.isDistinct == false, "Distinct should be false")
    }

    func testBasicQuery() throws {
        let query = try DummyModel.makeQuery().filter("name", "Vapor")

        guard
            let filter = query.filters.first?.wrapped,
            query.filters.count == 1
        else {
            XCTFail("Should be one filter")
            return
        }

        guard case .compare(let key, let comparison, let value) = filter.method else {
            XCTFail("Should be compare filter")
            return
        }

        XCTAssert(key == "name", "Key should be name")
        XCTAssert(comparison == .equals, "Comparison should be equals")
        XCTAssert(value.string == "Vapor", "Value should be vapor")
    }

    func testLikeQuery() throws {
        let query = try DummyModel.makeQuery().filter("name", .hasPrefix, "Vap")

        guard
            let filter = query.filters.first?.wrapped,
            query.filters.count == 1
        else {
            XCTFail("Should be one filter")
            return
        }

        guard case .compare(let key, let comparison, let value) = filter.method else {
            XCTFail("Should be a compare filter")
            return
        }

        XCTAssert(key == "name", "Key should be name")
        XCTAssert(comparison == .hasPrefix, "Position should be start")
        XCTAssert(value.string == "Vap", "Value should be Vap")
    }
 
    func testCountQuery() throws {
        let query = try DummyModel.makeQuery().filter(DummyModel.idKey, 5)

        do {
            let numberOfResults = try query.count()
            XCTAssertEqual(numberOfResults, 0)
        } catch {
            XCTFail("Count should not have failed")
        }
        
        XCTAssert(query.action == .aggregate(field: nil, .count))
    }

    func testDeleteQuery() throws {
        let query = try DummyModel.makeQuery().filter(DummyModel.idKey, 5)

        do {
            try query.delete()
        } catch {
            XCTFail("Delete should not have failed")
        }

        XCTAssert(query.action == .delete)
    }
  
    func testLimitQuery() throws {
        let query = try DummyModel.makeQuery().limit(5)
        XCTAssertEqual(query.limits.first?.wrapped?.count, 5)
    }

    func testDistinctQuery() throws {
        let query = try DummyModel.makeQuery().distinct()
        XCTAssert(query.isDistinct)
    }
}
