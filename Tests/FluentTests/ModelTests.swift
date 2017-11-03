import Async
import Fluent
import FluentBenchmark
import FluentSQLite
import SQLite
import XCTest

final class SQLiteBencharkTests: XCTestCase {
    var benchmarker: Benchmarker<SQLiteDatabase>!

    override func setUp() {
        let database = SQLiteDatabase(storage: .memory)
        benchmarker = Benchmarker(database, onFail: XCTFail)
    }

    func testSchema() throws {
        try benchmarker.benchmarkSchema()
    }

    func testModels() throws {
        try benchmarker.benchmarkModels_withSchema()
    }

//    func testCreate() throws {
//        // save user
//        let conn = try User.makeTestConnection()
//        let user = User(name: "Vapor", age: 2)
//        try user.save(on: conn).blockingAwait()
//    }
//
//    func testRead() throws {
//        // save user
//        let conn = try User.makeTestConnection()
//        let user = User(name: "Vapor", age: 2)
//        try user.save(on: conn).blockingAwait()
//
//        // find user
//        let found = try! User.find(user.id!, on: conn).blockingAwait()
//        XCTAssertNotNil(found)
//    }
//
//    func testUpdate() throws {
//        let conn = try User.makeTestConnection()
//
//        // save user
//        let user = User(name: "Vapor", age: 2)
//        try user.save(on: conn).blockingAwait()
//        XCTAssertNotNil(user.id)
//
//        // create user w/ same id and save
//        let copy = User(id: user.id, name: user.name, age: 3)
//        try copy.save(on: conn).blockingAwait()
//
//        // get user table count
//        let count = try QueryBuilder(User.self, on: conn).count().blockingAwait()
//        XCTAssertEqual(count, 1)
//    }
//
//    func testDelete() throws {
//        let conn = try User.makeTestConnection()
//
//        // save user
//        let user = User(name: "Vapor", age: 2)
//        try user.save(on: conn).blockingAwait()
//        XCTAssertNotNil(user.id)
//
//        // get user table count
//        let count = try QueryBuilder(User.self, on: conn).count().blockingAwait()
//        XCTAssertEqual(count, 1)
//
//        // create user w/ same id and save
//        try user.delete(on: conn).blockingAwait()
//
//        // get user table count
//        let recount = try QueryBuilder(User.self, on: conn).count().blockingAwait()
//        XCTAssertEqual(recount, 0)
//    }

    static let allTests = [
        ("testModels", testModels),
    ]
}
