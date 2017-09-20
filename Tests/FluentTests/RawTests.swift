import XCTest
@testable import Fluent

class RawTests: XCTestCase {
    static let allTests = [
        ("testBasic", testBasic),
        ("testWithValues", testWithValues),
        ("testRawFilter", testRawFilter),
        ("testRawJoinsAndFilters", testRawJoinsAndFilters),
        ("testRawSet", testRawSet),
        ("testRawGet", testRawGet),
        ("testRawLimit", testRawLimit),
        ("testRawSort", testRawSort)
    ]

    var lqd: LastQueryDriver!
    var db: Database!

    override func setUp(){
        lqd = LastQueryDriver()
        db = Database(lqd)
        Compound.database = db
        Atom.database = db
    }

    func testBasic() throws {
        try db.raw("custom string action")
        XCTAssertEqual(lqd.lastRaw?.0, "custom string action")
        XCTAssertEqual(lqd.lastRaw?.1.count, 0)
    }

    func testWithValues() throws {
        try db.raw("custom action string", [1, "hello"])
        XCTAssertEqual(lqd.lastRaw?.0, "custom action string")
        XCTAssertEqual(lqd.lastRaw?.1.count, 2)
    }
    
    
    func testRawFilter() throws {
        let query = Query<User>(db)
        try query.filter("name", "bob")
        try query.filter(raw: "aGe ~~ ?", [22])
        
        let (statement, values) = serialize(query)
        
        XCTAssertEqual(statement, "SELECT `users`.* FROM `users` WHERE `users`.`name` = ? AND aGe ~~ ?")
        XCTAssertEqual(values.count, 2)
    }
    
    func testRawJoinsAndFilters() throws {
        let query = Query<Compound>(db)
        try query.join(Atom.self)
        try query.filter(Atom.self, "size", 42)
        try query.filter(raw: "`foo`.aGe ~~ ?", [22])
        try query.join(raw: "JOIN `foo` ON `users`.BAR !~ `foo`.🚀")
        
        let (statement, values) = serialize(query)
        
        XCTAssertEqual(statement, "SELECT `compounds`.* FROM `compounds` INNER JOIN `atoms` ON `compounds`.`#id` = `atoms`.`compound_#id` JOIN `foo` ON `users`.BAR !~ `foo`.🚀 WHERE `atoms`.`size` = ? AND `foo`.aGe ~~ ?")
        XCTAssertEqual(values.count, 2)
    }
    
    func testRawSet() throws {
        let query = Query<Compound>(db)
        try query.set(raw: "id", equals: "UUID()")
        query.action = .modify
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "UPDATE `compounds` SET id = UUID()")
        XCTAssertEqual(values.count, 0)
    }
    
    func testRawGet() throws {
        let query = Query<Compound>(db)
        query.action = .fetch([
            .some(ComputedField(function: "UUID", key: "test"))
        ])
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "SELECT `compounds`.*, UUID() as `test` FROM `compounds`")
        XCTAssertEqual(values.count, 0)
    }
    
    func testRawLimit() throws {
        let query = Query<Compound>(db)
        try query.limit(raw: "max(foo)")
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "SELECT `compounds`.* FROM `compounds` LIMIT max(foo)")
        XCTAssertEqual(values.count, 0)
    }
    
    func testRawSort() throws {
        let query = Query<Compound>(db)
        try query.sort(raw: "foo ASC")
        let (statement, values) = serialize(query)
        XCTAssertEqual(statement, "SELECT `compounds`.* FROM `compounds` ORDER BY foo ASC")
        XCTAssertEqual(values.count, 0)
    }
}
