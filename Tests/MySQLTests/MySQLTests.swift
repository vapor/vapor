import Async
import Service
import Dispatch
import XCTest
import Async
import TCP
@testable import MySQL
import JunkDrawer

/// Requires a user with the username `vapor` and password `vapor` with permissions on the `vapor_test` database on localhost
class MySQLTests: XCTestCase {
    static let poolQueue = DispatchEventLoop(label: "multi")
    
    var connection: MySQLConnection!

    static let allTests = [
        ("testPreparedStatements", testPreparedStatements),
        ("testCreateUsersSchema", testCreateUsersSchema),
        ("testPopulateUsersSchema", testPopulateUsersSchema),
        ("testForEach", testForEach),
        ("testAll", testAll),
        ("testStream", testStream),
        ("testComplexModel", testComplexModel),
        ("testFailures", testFailures),
        ("testSingleValueDecoding", testSingleValueDecoding),
    ]
    
    override func setUp() {
        connection = try! MySQLConnection.makeConnection(
            hostname: "localhost",
            user: "root",
            password: nil,
            database: "vapor_test",
            on: MySQLTests.poolQueue
        ).blockingAwait(timeout: .seconds(10))
        
        _ = try? connection.dropTables(named: "users").blockingAwait(timeout: .seconds(3))
        _ = try? connection.dropTables(named: "complex").blockingAwait(timeout: .seconds(3))
        _ = try? connection.dropTables(named: "test").blockingAwait(timeout: .seconds(3))
    }

    func testPreparedStatements() throws {
        try testPopulateUsersSchema()
        
        let query = "SELECT * FROM users WHERE `username` = ?"
        
        let users = try connection.withPreparation(statement: query) { statement in
            return try statement.bind { binding in
                try binding.bind("Joannis")
            }.all(User.self)
        }.blockingAwait(timeout: .seconds(15))
        
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.username, "Joannis")
    }
    
    func testCreateUsersSchema() throws {
        let table = Table(named: "users")
     
        table.schema.append(Table.Column(named: "id", type: .int16(length: nil), autoIncrement: true, primary: true, unique: true))
     
        table.schema.append(Table.Column(named: "username", type: .varChar(length: 32, binary: false), autoIncrement: false, primary: false, unique: false))
     
        try connection.createTable(table).blockingAwait(timeout: .seconds(003))
    }
    
    func testPopulateUsersSchema() throws {
        try testCreateUsersSchema()
     
        try connection.administrativeQuery("INSERT INTO users (username) VALUES ('Joannis')").blockingAwait(timeout: .seconds(3))
        try connection.administrativeQuery("INSERT INTO users (username) VALUES ('Jonas')").blockingAwait(timeout: .seconds(3))
        try connection.administrativeQuery("INSERT INTO users (username) VALUES ('Logan')").blockingAwait(timeout: .seconds(3))
        try connection.administrativeQuery("INSERT INTO users (username) VALUES ('Tanner')").blockingAwait(timeout: .seconds(3))
    }
    
    func testForEach() throws {
        try testPopulateUsersSchema()
     
        var iterator = ["Joannis", "Jonas", "Logan", "Tanner"].makeIterator()
        var count = 0
        
        try connection.forEach(User.self, in: "SELECT * FROM users") { user in
            XCTAssertEqual(user.username, iterator.next())
            count += 1
        }.blockingAwait(timeout: .seconds(3))
        
        XCTAssertEqual(count, 4)
    }

    func testAll() throws {
        try testPopulateUsersSchema()
     
        var iterator = ["Joannis", "Jonas", "Logan", "Tanner"].makeIterator()
     
        let users = try connection.all(User.self, in: "SELECT * FROM users").blockingAwait(timeout: .seconds(3))
        for user in users {
            XCTAssertEqual(user.username, iterator.next())
        }
        
        XCTAssertEqual(users.count, 4)
    }
    
    func testStream() throws {
        try testPopulateUsersSchema()
     
        var iterator = ["Joannis", "Jonas", "Logan", "Tanner"].makeIterator()
        var count = 0
        let promise = Promise<Int>()
     
        connection.forEach(User.self, in: "SELECT * FROM users") { user in
            XCTAssertEqual(user.username, iterator.next())
            count += 1
            
            if count == 4 {
                promise.complete(4)
            }
        }.catch { XCTFail("\($0)") }
            
        XCTAssertEqual(4, try promise.future.blockingAwait(timeout: .seconds(3)))
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
            try connection.createTable(table).blockingAwait(timeout: .seconds(3))
     
            try connection.administrativeQuery("INSERT INTO complex (number0, number1, i16, ui16, i32, ui32, i64, ui64) VALUES (3.14, 6.28, -5, 5, -10000, 10000, 5000, 0)").blockingAwait(timeout: .seconds(3))
     
            try connection.administrativeQuery("INSERT INTO complex (number0, number1, i16, ui16, i32, ui32, i64, ui64) VALUES (3.14, 6.28, -5, 5, -10000, 10000, 5000, 0)").blockingAwait(timeout: .seconds(3))
        } catch {
            debugPrint(error)
            XCTFail()
            throw error
        }
     
        let all = try connection.all(Complex.self, in: "SELECT * FROM complex").blockingAwait(timeout: .seconds(3))
     
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
     
        try connection.dropTable(named: "complex").blockingAwait(timeout: .seconds(3))
    }
    
    func testSingleValueDecoding() throws {
        try testPopulateUsersSchema()
        
        let tables = try connection.all(String.self, in: "SHOW TABLES").blockingAwait()
        XCTAssertEqual(tables, ["users"])
    }
    
    func testFailures() throws {
        XCTAssertThrowsError(try connection.administrativeQuery("INSERT INTO users (username) VALUES ('Exampleuser')").blockingAwait(timeout: .seconds(3)))
        XCTAssertThrowsError(try connection.all(User.self, in: "SELECT * FORM users").blockingAwait(timeout: .seconds(3)))
    }
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

struct Test: Decodable {
    var id: Int
    var num: Int
}
