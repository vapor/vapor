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
        let connection = try Connection(hostname: "localhost", user: "root", password: nil, database: "test", queue: .global())
        
        XCTAssert(try connection.currentQueryFuture?.sync(timeout: .seconds(10)) ?? true)
        
//        try connection.query("SELECT * from users").drain { row in
//            print(row)
//        }
        
        try User.query("SELECT * from users", onConnection: connection).drain { user in
            print(user)
        }
        
//        let results = try User.query("SELECT * from users", onConnection: connection)
        
//        print(try results.await(for: .seconds(5)))
        
//        let results = try connection.query("SELECT @@version, @@version, 1337, 3.14, 'what up', NULL")
//
//        do {
//            let ok = try results.await()
//
//            print(ok)
//        } catch {
//            print(error)
//        }
        sleep(5000)
    }
}

struct User : Table {
    var id: Int
    var username: String
}
