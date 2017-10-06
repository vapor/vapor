import Async
import Dispatch
@testable import SQLite
import XCTest

class SQLiteTests: XCTestCase {
    var database: Connection!
    var queue: DispatchQueue!

    override func setUp() {
        self.queue = DispatchQueue(label: "sqlite.tests.queue")
        self.database = Connection.makeTestConnection(queue: queue)
    }

    func testTables() {
        try! database.query("select * From foo").drain { row in
            print(row)
        }.catch { error in
            print("failed: \(error)")
        }

        try! database.query("DROP TABLE IF EXISTS foo").execute().sync()
        try! database.query("CREATE TABLE foo (bar INT(4), baz VARCHAR(16), biz FLOAT)").execute().sync()
        try! database.query("INSERT INTO foo VALUES (42, 'Life', 0.44)").execute().sync()
        try! database.query("INSERT INTO foo VALUES (1337, 'Elite', 209.234)").execute().sync()
        try! database.query("INSERT INTO foo VALUES (9, NULL, 34.567)").execute().sync()

        if let resultBar = try! database.query("SELECT * FROM foo WHERE bar = 42").all().sync().first {
            XCTAssertEqual(resultBar["bar"]?.integer, 42)
            XCTAssertEqual(resultBar["baz"]?.text, "Life")
            XCTAssertEqual(resultBar["biz"]?.float, 0.44)
        } else {
            XCTFail("Could not get bar result")
        }


        if let resultBaz = try! database.query("SELECT * FROM foo where baz = 'Elite'").all().sync().first {
            XCTAssertEqual(resultBaz["bar"]?.integer, 1337)
            XCTAssertEqual(resultBaz["baz"]?.text, "Elite")
        } else {
            XCTFail("Could not get baz result")
        }

        if let resultBaz = try! database.query("SELECT * FROM foo where bar = 9").all().sync().first {
            XCTAssertEqual(resultBaz["bar"]?.integer, 9)
            XCTAssertEqual(resultBaz["baz"]?.isNull, true)
        } else {
            XCTFail("Could not get null result")
        }
    }

    func testUnicode() {
        /// This string includes characters from most Unicode categories
        /// such as Latin, Latin-Extended-A/B, Cyrrilic, Greek etc.
        let unicode = "®¿ÐØ×ĞƋƢǂǊǕǮȐȘȢȱȵẀˍΔῴЖ♆"
        try! database.query("DROP TABLE IF EXISTS `foo`").execute().sync()
        try! database.query("CREATE TABLE `foo` (bar TEXT)").execute().sync()

        try! database.query("INSERT INTO `foo` VALUES(?)")
            .bind(unicode)
            .drain
            .execute()
            .sync()


        let selectAllResults = try! database.query("SELECT * FROM `foo`").all().sync().first
        XCTAssertNotNil(selectAllResults)
        XCTAssertEqual(selectAllResults!["bar"]?.text, unicode)

        let selectWhereResults = try! database.query("SELECT * FROM `foo` WHERE bar = '\(unicode)'").all().sync().first
        XCTAssertNotNil(selectWhereResults)
        XCTAssertEqual(selectWhereResults!["bar"]?.text, unicode)
    }

    func testBigInts() throws {
        let max = Int.max

        try! database.query("DROP TABLE IF EXISTS foo").execute().sync()
        try! database.query("CREATE TABLE foo (max INT)").execute().sync()
        try! database.query("INSERT INTO foo VALUES (?)")
            .bind(max)
            .execute()
            .sync()

        if let result = try! database.query("SELECT * FROM foo").all().sync().first {
            XCTAssertEqual(result["max"]?.integer, max)
        }
    }

    func testBlob() {
        let data = Data(bytes: [0, 1, 2])

        try! database.query("DROP TABLE IF EXISTS `foo`").execute().sync()
        try! database.query("CREATE TABLE foo (bar BLOB(4))").execute().sync()
        try! database.query("INSERT INTO foo VALUES (?)")
            .bind(data)
            .execute()
            .sync()

        if let result = try! database.query("SELECT * FROM foo").all().sync().first {
            XCTAssertEqual(result["bar"]!.blob, data)
        } else {
            XCTFail()
        }
    }

    func testError() {
        do {
            try database.query("asdf").execute().sync()
            XCTFail("Should have errored")
        } catch let error as SQLite.Error {
            print(error)
            XCTAssert(error.reason.contains("syntax error"))
        } catch {
            XCTFail("wrong error")
        }
    }

    static let allTests = [
        ("testTables", testTables),
        ("testUnicode", testUnicode),
        ("testBigInts", testBigInts),
        ("testBlob", testBlob),
        ("testError", testError)
    ]
}
