import XCTest
@testable import MySQL
//import JSON
import Core

class MySQLTests: XCTestCase {
    static let allTests = [
        ("testExample", testExample)
    ]

    func testExample() throws {
        let connection = try Connection(
            hostname: "localhost",
            user: "root",
            password: nil,
            database: "test",
            queue: .global()
        )
        
        XCTAssert(try connection.currentQueryFuture?.sync(timeout: .seconds(1)) ?? true)
        
        try User.forEach("SELECT * from users", on: connection) { user in
            print(user)
        }

        sleep(1000)
    }
}

struct User: Table {
    var id: Int
    var username: String
}
