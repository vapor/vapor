import Fluent
import SQLite
import XCTest

final class DatabaseTests: XCTestCase {
    var conn: DatabaseConnection!

    override func setUp() {
        conn = try! SQLiteDatabase(storage: .memory)
            .makeConnection(on: .main)
    }

    func testCreate() {
        let user = User(id: nil, name: "Vapor", age: 2)
        try! user.makeQuery(on: conn).save().sync()
    }

    func testInsert() {
        let user = User(id: nil, name: "Vapor", age: 2)
        try! user.makeQuery(on: conn).save().sync()
    }
}
