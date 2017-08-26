import XCTest
@testable import MySQL
//import JSON
import Core

class MySQLTests: XCTestCase {
    static let allTests = [
        ("testExample", testExample)
//        ("testSelectVersion", testSelectVersion),
//        ("testTables", testTables),
//        ("testParameterization", testParameterization),
//        ("testDates", testDates),
//        ("testTimestamps", testTimestamps),
//        ("testSpam", testSpam),
//        ("testError", testError),
//        ("testTransaction", testTransaction),
//        ("testTransactionFailed", testTransactionFailed),
//        ("testBlob", testBlob),
//        ("testLongtext", testLongtext),
    ]

    override func setUp() {
        
    }
    
    func testExample() throws {
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
    var id: Int
    var username: String
}
