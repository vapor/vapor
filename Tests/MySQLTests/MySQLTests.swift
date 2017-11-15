import Dispatch
import XCTest
import Async
import TCP
@testable import MySQL
import Core

class MySQLTests: XCTestCase {
    let pool = ConnectionPool(hostname: "127.0.0.1", user: "root", password: "", database: "test", worker: Worker(queue: .global()))

    static let allTests = [
        ("testNothing", testNothing),
    ]

    func testNothing() {
        // hi
    }
//    func testVersion() {
//        let group = DispatchGroup()
//        group.enter()
//        try! pool.forEach([[String: String]].self, in: "SELECT @@version;") { version in
//            print(version)
//            group.leave()
//        }
//        group.wait()
//    }
    /*
    static let allTests = [
        ("testCreateUsersSchema", testCreateUsersSchema),
        ("testPopulateUsersSchema", testPopulateUsersSchema),
        ("testForEach", testForEach),
        ("testAll", testAll),
        ("testStream", testStream),
        ("testFailures", testFailures),
    ]
    
    override func setUp() {
        _ = try? pool.dropTables(named: "users", "complex").blockingAwait()
    }

    
    func testCreateUsersSchema() throws {
        let table = Table(named: "users")
        
        table.schema.append(Table.Column(named: "id", type: .int8(length: nil), autoIncrement: true, primary: true, unique: true))
        
        table.schema.append(Table.Column(named: "username", type: .varChar(length: 32, binary: false), autoIncrement: false, primary: false, unique: false))
        
        try pool.createTable(table).blockingAwait()
    }
    
    func testPopulateUsersSchema() throws {
        try testCreateUsersSchema()
        
        try pool.query("INSERT INTO users (username) VALUES ('Joannis')").blockingAwait()
        try pool.query("INSERT INTO users (username) VALUES ('Logan')").blockingAwait()
        try pool.query("INSERT INTO users (username) VALUES ('Tanner')").blockingAwait()
    }

    
    func testForEach() throws {
        try testPopulateUsersSchema()
        
        var iterator = ["Joannis", "Logan", "Tanner"].makeIterator()
        
        try pool.forEach(User.self, in: "SELECT * FROM users") { user in
            XCTAssertEqual(user.username, iterator.next())
        }
    }

    func testAll() throws {
        try testPopulateUsersSchema()
        
        var iterator = ["Joannis", "Logan", "Tanner"].makeIterator()
        
        let users = try pool.all(User.self, in: "SELECT * FROM users").blockingAwait()
        
        for user in users {
            XCTAssertEqual(user.username, iterator.next())
        }
    }
    
    func testStream() throws {
        try testPopulateUsersSchema()
        
        var iterator = ["Joannis", "Logan", "Tanner"].makeIterator()
        
        try pool.stream(User.self, in: "SELECT * FROM users").drain { user in
            XCTAssertEqual(user.username, iterator.next())
        }
    }
    
    func testComplexModel() throws {
        let table = Table(named: "complex")
        
        table.schema.append(Table.Column(named: "id", type: .uint8(length: nil), autoIncrement: true, primary: true, unique: true))
        
        table.schema.append(Table.Column(named: "number0", type: .float()))
        table.schema.append(Table.Column(named: "number1", type: .double()))
        table.schema.append(Table.Column(named: "i16", type: .int16()))
        table.schema.append(Table.Column(named: "ui16", type: .uint16()))
        table.schema.append(Table.Column(named: "i32", type: .int32()))
        table.schema.append(Table.Column(named: "ui32", type: .uint32()))
        table.schema.append(Table.Column(named: "i64", type: .int64()))
        table.schema.append(Table.Column(named: "ui64", type: .uint64()))
        
        do {
            try pool.createTable(table).blockingAwait()
            
            try pool.query("INSERT INTO complex (number0, number1, i16, ui16, i32, ui32, i64, ui64) VALUES (3.14, 6.28, -5, 5, -10000, 10000, 5000, 0)").blockingAwait()
            
            try pool.query("INSERT INTO complex (number0, number1, i16, ui16, i32, ui32, i64, ui64) VALUES (3.14, 6.28, -5, 5, -10000, 10000, 5000, 0)").blockingAwait()
        } catch {
            debugPrint(error)
            XCTFail()
            throw error
        }
        
        let all = try pool.all(Complex.self, in: "SELECT * FROM complex").blockingAwait()
        
        XCTAssertEqual(all.count, 2)
        
        guard let first = all.first else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(first.number0, 3.14)
        XCTAssertEqual(first.number1, 6.28)
        XCTAssertEqual(first.i16, -5)
        XCTAssertEqual(first.ui16, 5)
        XCTAssertEqual(first.i32, -10_000)
        XCTAssertEqual(first.ui32, 10_000)
        XCTAssertEqual(first.i64, 5_000)
        XCTAssertEqual(first.ui64, 0)
        
        try pool.dropTable(named: "complex").blockingAwait()
    }
    
    func testFailures() throws {
        XCTAssertThrowsError(try pool.query("INSERT INTO users (username) VALUES ('Exampleuser')").blockingAwait())
        XCTAssertThrowsError(try pool.all(User.self, in: "SELECT * FORM users").blockingAwait())
    }
     */
}

struct User: Decodable {
    var id: Int
    var username: String
}

struct Complex: Decodable {
    var id: Int
    var number0: Float
    var number1: Double
    var i16: Int16
    var ui16: UInt16
    var i32: Int32
    var ui32: UInt32
    var i64: Int64
    var ui64: UInt64
}
