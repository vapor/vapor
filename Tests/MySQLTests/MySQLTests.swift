import XCTest
@testable import MySQL
//import JSON
import Core

class MySQLTests: XCTestCase {
    static let allTests = [
        ("testExample", testExample)
    ]

    func testExample() throws {
<<<<<<< HEAD
        let pool = ConnectionPool(hostname: "localhost", user: "root", password: nil, database: "test", queue: .global())
        
//        try connection.query("SELECT * from users").drain { row in
//            print(row)
//        }
        
        try pool.forEach(User.self, in: "SELECT * from users") { user in
            print(user)
        }
        
        sleep(5000)
    }
}

struct User : Decodable {
=======
        let connection = try Connection(
            hostname: "localhost",
            user: "ubuntu",
            password: nil,
            database: "circle_test",
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
>>>>>>> 36d856c22e5574b74bfcadaf116de8cc9aa5b61f
    var id: Int
    var username: String
}
