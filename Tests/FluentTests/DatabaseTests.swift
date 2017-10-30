import Async
import Fluent
import SQLite
import XCTest

final class DatabaseTests: XCTestCase {
    var conn: DatabaseConnection!

    override func setUp() {
        let futureConn = SQLiteDatabase(storage: .memory)
            .makeConnection(on: EventLoop.default) as Future<DatabaseConnection>
        conn = try! futureConn.blockingAwait()
    }

    func testCreate() {
        var user = User(id: nil, name: "Vapor", age: 2)
        try! user.save(to: conn).blockingAwait()
    }

    func testInsert() {
        var user = User(id: nil, name: "Vapor", age: 2)
        try! user.save(to: conn).blockingAwait()
    }
}
