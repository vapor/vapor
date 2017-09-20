import XCTest
@testable import Fluent

class SQLSerializerTests: XCTestCase {
    var db: Database!

    override func setUp() {
        let lqd = LastQueryDriver()
        db = Database(lqd)
    }

    func testBasicSelect() {
        let query = Query<Atom>(db)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT `atoms`.* FROM `atoms`")
        XCTAssert(values.isEmpty)
    }
    
    func testDistinctSelect() throws {
        let query = try Query<Atom>(db).distinct()
        let (statement, values) = serialize(query)
        
        XCTAssertEqual(statement, "SELECT DISTINCT `atoms`.* FROM `atoms`")
        XCTAssert(values.isEmpty)
    }

    func testRegularSelect() throws {
        let filter = Filter(User.self, .compare("age", .greaterThanOrEquals, 21))
        let query = Query<User>(db)
        query.filters.append(filter)
        try query.limit(5)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT `users`.* FROM `users` WHERE `users`.`age` >= ? LIMIT 0, 5")
        XCTAssertEqual(values.first?.int, 21)
        XCTAssertEqual(values.count, 1)
    }
    
    func testOffsetSelect() throws {
        let filter = Filter(User.self, .compare("age", .greaterThanOrEquals, 21))
        let query = Query<User>(db)
        query.filters.append(filter)
        try query.limit(5, offset: 15)
        let (statement, values) = serialize(query)
        
        XCTAssertEqual(statement, "SELECT `users`.* FROM `users` WHERE `users`.`age` >= ? LIMIT 15, 5")
        XCTAssertEqual(values.count, 1)
    }

    func testFilterCompareSelect() {
        let filter = Filter(User.self, .compare("name", .notEquals, "duck"))
        let query = Query<User>(db)
        query.filters.append(filter)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT `users`.* FROM `users` WHERE `users`.`name` != ?")
        XCTAssertEqual(values.first?.string, "duck")
        XCTAssertEqual(values.count, 1)
    }

    func testFilterLikeSelect() {
        let filter = Filter(User.self, .compare("name", .hasPrefix, "duc"))
        let query = Query<User>(db)
        query.filters.append(filter)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT `users`.* FROM `users` WHERE `users`.`name` LIKE ?")
        XCTAssertEqual(values.first?.string, "duc%")
        XCTAssertEqual(values.count, 1)
    }

    func testBasicCount() {
        let query = Query<User>(db)
        query.action = .aggregate(field: "*", .count)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT COUNT(*) as _fluent_aggregate FROM `users`")
        XCTAssert(values.isEmpty)
    }
    
    func testDistinctCount() {
        let query = Query<User>(db)
        query.action = .aggregate(field: "*", .count)
        query.isDistinct = true
        let (statement, values) = serialize(query)
        
        XCTAssertEqual(statement, "SELECT DISTINCT COUNT(*) as _fluent_aggregate FROM `users`")
        XCTAssert(values.isEmpty)
    }

    func testRegularCount() throws {
        let query = Query<User>(db)
        query.action = .aggregate(field: "*", .count)
        try query.filter("age", .greaterThanOrEquals, 21)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT COUNT(*) as _fluent_aggregate FROM `users` WHERE `users`.`age` >= ?")
        XCTAssertEqual(values.first?.int, 21)
        XCTAssertEqual(values.count, 1)
    }

    func testFilterCompareCount() throws {
        let query = Query<User>(db)
        query.action = .aggregate(field: "*", .count)
        try query.filter("name", .notEquals, "duck")
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT COUNT(*) as _fluent_aggregate FROM `users` WHERE `users`.`name` != ?")
        XCTAssertEqual(values.first?.string, "duck")
        XCTAssertEqual(values.count, 1)
    }

    func testFilterLikeCount() throws {
        let query = Query<User>(db)
        query.action = .aggregate(field: "*", .count)
        try query.filter("name", .hasPrefix, "duc")
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT COUNT(*) as _fluent_aggregate FROM `users` WHERE `users`.`name` LIKE ?")
        XCTAssertEqual(values.first?.string, "duc%")
        XCTAssertEqual(values.count, 1)
    }

    func testReqularSum() throws {
        let query = Query<User>(db)
        query.action = .aggregate(field: "age", .sum)
        let (statement, values) = serialize(query)
        
        XCTAssertEqual(statement, "SELECT SUM(`users`.`age`) as _fluent_aggregate FROM `users`")
        XCTAssertEqual(values.count, 0)
    }
    
    func testCustomAggregate() throws {
        let query = Query<User>(db)
        query.action = .aggregate(field: "job", .custom(string: "NOTHING"))
        let (statement, values) = serialize(query)
        
        XCTAssertEqual(statement, "SELECT NOTHING(`users`.`job`) as _fluent_aggregate FROM `users`")
        XCTAssertEqual(values.count, 0)
    }
    
    func testFilterEqualsNullSelect() throws {
        let query = Query<User>(db)
        try query.filter("name", .equals, Node.null)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT `users`.* FROM `users` WHERE `users`.`name` IS NULL")
        XCTAssertEqual(values.count, 0)
    }
    
    func testFilterNotEqualsNullSelect() throws {
        let query = Query<User>(db)
        try query.filter("name", .notEquals, Node.null)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT `users`.* FROM `users` WHERE `users`.`name` IS NOT NULL")
        XCTAssertEqual(values.count, 0)
    }

    func testFilterCompareUpdate() throws {
        let query = Query<User>(db)
        try query.filter("name", "duck")
        query.data = [.some("not it"): .some(true)]
        query.action = .modify
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "UPDATE `users` SET `not it` = ? WHERE `users`.`name` = ?")
        XCTAssertEqual(values.first?.bool, true)
        XCTAssertEqual(values.last?.string, "duck")
        XCTAssertEqual(values.count, 2)
    }

    func testFilterCompareDelete() throws {
        let query = Query<User>(db)
        try query.filter("name", .greaterThan, "duck")
        query.action = .delete
        let (statement, values) = serialize(query)


        XCTAssertEqual(statement, "DELETE FROM `users` WHERE `users`.`name` > ?")
        XCTAssertEqual(values.first?.string, "duck")
        XCTAssertEqual(values.count, 1)
    }

    func testFilterGroup() throws {
        let query = Query<User>(db)
        try query.filter("1", 1)
        try query.or { try $0.filter("2", 2).filter("3", 3) }
        try query.filter("4", 4)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT `users`.* FROM `users` WHERE `users`.`1` = ? AND (`users`.`2` = ? OR `users`.`3` = ?) AND `users`.`4` = ?")
        XCTAssertEqual(values.count, 4)
    }

    func testSort() throws {
        let adult = Filter(User.self, .compare("age", .greaterThan, 17))
        let name = Sort(User.self, "name", .ascending)

        let query = Query<User>(db)
        try query.filter(adult)
        try query.sort(name)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT `users`.* FROM `users` WHERE `users`.`age` > ? ORDER BY `users`.`name` ASC")
        XCTAssertEqual(values.count, 1)
    }

    func testSortMultiple() throws {
        let adult = Filter(User.self, .compare("age", .greaterThan, 17))
        let name = Sort(User.self, "name", .ascending)
        let email = Sort(User.self, "email", .descending)

        let query = Query<User>(db)
        try query.filter(adult)
        try query.sort(name)
        try query.sort(email)
        let (statement, values) = serialize(query)

        XCTAssertEqual(statement, "SELECT `users`.* FROM `users` WHERE `users`.`age` > ? ORDER BY `users`.`name` ASC, `users`.`email` DESC")
        XCTAssertEqual(values.count, 1)
    }
    
    func testJoinedDelete() throws {
        let query = Query<Compound>(db)
        try query.join(Atom.self)
        try query.filter(Atom.self, "name", "Hydrogen")
        try query.delete()
        
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "DELETE `compounds` FROM `compounds` INNER JOIN `atoms` ON `compounds`.`id` = `atoms`.`compound_id` WHERE `atoms`.`name` = ?")
        XCTAssertEqual(values.count, 1)
    }

    func testNull() throws {
        let query = Query<Compound>(db)
        let string: String? = nil
        try query.filter("foo", string)
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "SELECT `compounds`.* FROM `compounds` WHERE `compounds`.`foo` IS NULL")
        XCTAssertEqual(values.count, 0)
    }

    func testNotNull() throws {
        let query = Query<Compound>(db)
        let string: String? = nil
        try query.filter("foo", .notEquals, string)
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "SELECT `compounds`.* FROM `compounds` WHERE `compounds`.`foo` IS NOT NULL")
        XCTAssertEqual(values.count, 0)
    }

    func testNodeNull() throws {
        let query = Query<Compound>(db)
        try query.filter("foo", Node.null)
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "SELECT `compounds`.* FROM `compounds` WHERE `compounds`.`foo` IS NULL")
        XCTAssertEqual(values.count, 0)
    }

    func testPlainNil() throws {
        let query = Query<Compound>(db)
        try query.filter("foo", nil)
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "SELECT `compounds`.* FROM `compounds` WHERE `compounds`.`foo` IS NULL")
        XCTAssertEqual(values.count, 0)
    }

    func testEmptyIn() throws {
        let query = Query<Compound>(db)
        try query.filter(.subset("foo", .in, []))
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "SELECT `compounds`.* FROM `compounds` WHERE false")
        XCTAssertEqual(values.count, 0)
    }

    func testEmptyNotIn() throws {
        let query = Query<Compound>(db)
        try query.filter(.subset("foo", .notIn, []))
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "SELECT `compounds`.* FROM `compounds` WHERE true")
        XCTAssertEqual(values.count, 0)
    }

    func testDirty() throws {
        let atom = Atom(name: "Hydrogen", id: 42)
        atom.exists = true
        
        do {
            atom.storage.fetchedRow = try Row(node: ["name": "Foo"])
            let dirty = try atom.makeDirtyRow()
            XCTAssertEqual(dirty["name"]?.string, "Hydrogen")
        }
        
        do {
            atom.storage.fetchedRow = try Row(node: ["name": "Hydrogen"])
            let dirty = try atom.makeDirtyRow()
            XCTAssertNil(dirty["name"]?.string)
        }
    }

    static let allTests = [
        ("testBasicSelect", testBasicSelect),
        ("testDistinctSelect", testDistinctSelect),
        ("testRegularSelect", testRegularSelect),
        ("testOffsetSelect", testOffsetSelect),
        ("testFilterCompareSelect", testFilterCompareSelect),
        ("testFilterLikeSelect", testFilterLikeSelect),
        ("testBasicCount", testBasicCount),
        ("testDistinctCount", testDistinctCount),
        ("testRegularCount", testRegularCount),
        ("testFilterCompareCount", testFilterCompareCount),
        ("testFilterLikeCount", testFilterLikeCount),
        ("testReqularSum", testReqularSum),
        ("testcustomAggregate", testCustomAggregate),
        ("testFilterEqualsNullSelect", testFilterEqualsNullSelect),
        ("testFilterNotEqualsNullSelect", testFilterNotEqualsNullSelect),
        ("testFilterCompareUpdate", testFilterCompareUpdate),
        ("testFilterCompareDelete", testFilterCompareDelete),
        ("testFilterGroup", testFilterGroup),
        ("testSort", testSort),
        ("testSortMultiple", testSortMultiple),
        ("testJoinedDelete", testJoinedDelete),
        ("testNull", testNull),
        ("testNotNull", testNotNull),
        ("testNodeNull", testNodeNull),
        ("testPlainNil", testPlainNil),
        ("testEmptyIn", testEmptyIn),
        ("testEmptyNotIn", testEmptyNotIn),
        ("testDirty", testDirty)
    ]
}







