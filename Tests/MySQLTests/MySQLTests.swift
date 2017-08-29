import XCTest
@testable import MySQL
//import JSON
import Core

class MySQLTests: XCTestCase {
    static let allTests = [
        ("testExample", testExample)
    ]

    func testExample() throws {
        let pool = ConnectionPool(hostname: "localhost", user: "root", password: nil, database: "test", queue: .global())
        
//        try connection.forEachRow(in: "SELECT * from users").drain { row in
//            print(row)
//        }
        
        try pool.forEach(User.self, in: "SELECT * from users") { user in
            print(user)
        }
        
        
        
        
        sleep(5000)
    }
}

struct User: Decodable {
    var id: Int
    var username: String
}
