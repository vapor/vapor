import XCTest
@testable import MySQL
//import JSON
import Core

class MySQLTests: XCTestCase {
    static let allTests = [
        ("testExample", testExample)
    ]
    
    let pool = ConnectionPool(hostname: "localhost", user: "root", password: nil, database: "test", queue: .global())
    
    func testCreateSchema() throws {
        let table = Table(named: "users")
        
        table.schema.append(Table.Column(name: "id", type: .int8(length: nil), nullable: false, autoIncrement: true, primary: true, unique: true))
        
        table.schema.append(Table.Column(name: "username", type: .varChar(length: 32, binary: false), nullable: false, autoIncrement: false, primary: false, unique: false))
        
        do {
            try pool.createTable(table).sync()
            
            try pool.dropTable(named: "users").sync()
        } catch {
            debugPrint(error)
            throw error
        }
    }
    
    override func setUp() {
        _ = try? pool.allRows(in: "DROP TABLE users").sync()
    }

    func testExample() throws {
        
//        try connection.forEachRow(in: "SELECT * from users").drain { row in
//            print(row)
//        }
        
        do {
            try pool.forEach(User.self, in: "SELECT * from users") { user in
                print(user)
            }

            try pool.stream(User.self, in: "SELECT * FROM users").drain { user in
                print(user)
            }
            
            print(try pool.all(User.self, in: "SELECT * FROM users").sync())
        } catch {
            print(error)
        }
        
        
        sleep(5)
    }
}

struct User: Decodable {
    var id: Int
    var username: String
}
