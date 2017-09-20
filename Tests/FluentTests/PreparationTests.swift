import XCTest
import Fluent

class PreparationTests: XCTestCase {
    static let allTests = [
        ("testManualPreparation", testManualPreparation),
    ]

    func testManualPreparation() {
        let driver = TestSchemaDriver { schema in
            guard case .create(let fields, _) = schema else {
                XCTFail("Invalid schema")
                return
            }

            guard fields.count == 3 else {
                XCTFail("Invalid field count")
                return
            }

            guard case .int = fields[0].wrapped!.type else {
                XCTFail("Invalid first field")
                return
            }
            XCTAssertEqual(fields[0].wrapped?.name, "id")

            guard case .string(let colTwoLength) = fields[1].wrapped!.type else {
                XCTFail("Invalid second field")
                return
            }
            XCTAssertEqual(fields[1].wrapped?.name, "name")
            XCTAssertEqual(colTwoLength, nil)

            guard case .string(let colThreeLength) = fields[2].wrapped!.type else {
                XCTFail("Invalid second field")
                return
            }
            XCTAssertEqual(fields[2].wrapped?.name, "email")
            XCTAssertEqual(colThreeLength, 128)
        }

        let database = Database(driver)

        TestPreparation.testClosure = { builder in
            builder.int("id")
            builder.string("name")
            builder.string("email", length: 128)
        }

        do {
            try TestPreparation.prepare(database)
        } catch {
            XCTFail("Preparation failed: \(error)")
        }
    }
    
    func testStringIdentifiedModelPreparation() {
        let driver = TestSchemaDriver { schema in
            guard case .create(let fields, _) = schema else {
                XCTFail("Invalid schema")
                return
            }
            
            guard fields.count == 1 else {
                XCTFail("Invalid field count")
                return
            }
            
            guard case .id(let keyType) = fields[0].wrapped!.type else {
                XCTFail("Invalid first field \(fields[0])")
                return
            }
            
            guard case .custom(let length) = keyType, length == "STRING(10)" else {
                XCTFail("Invalid key type \(keyType) for id")
                return
            }
        }
        
        let database = Database(driver)
        
        do {
            try StringIdentifiedThing.prepare(database)
        } catch {
            XCTFail("Preparation failed: \(error)")
        }
    }

    func testModelPreparation() {
        let driver = TestSchemaDriver { schema in
            guard case .create(let fields, _) = schema else {
                XCTFail("Invalid schema")
                return
            }

            guard fields.count == 3 else {
                XCTFail("Invalid field count")
                return
            }

            guard case .id = fields[0].wrapped!.type else {
                XCTFail("Invalid first field")
                return
            }

            guard case .string(let colTwoLength) = fields[1].wrapped!.type else {
                XCTFail("Invalid second field")
                return
            }
            XCTAssertEqual(fields[1].wrapped!.name, "name")
            XCTAssertEqual(colTwoLength, nil)

            guard case .int = fields[2].wrapped!.type else {
                XCTFail("Invalid second field")
                return
            }
            XCTAssertEqual(fields[2].wrapped?.name, "age")
        }

        let database = Database(driver)

        do {
            try TestModel.prepare(database)
        } catch {
            XCTFail("Preparation failed: \(error)")
        }
    }
}

// MARK: Utilities

final class TestModel: Entity {
    var name: String
    var age: Int
    let storage = Storage()

    init(row: Row) throws {
        name = try row.get("name")
        age = try row.get("age")
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set("name", name)
        try row.set("age", age)
        return row
    }

    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string("name")
            builder.int("age")
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

class TestPreparation: Preparation {
    static var testClosure: (Creator) -> () = { _ in }

    static func prepare(_ database: Database) throws {
        try database.create(Atom.self) { builder in
            self.testClosure(builder)
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete(Atom.self)
    }
}

class TestSchemaDriver: Driver {
    var keyNamingConvention: KeyNamingConvention = .snake_case
    var idType: IdentifierType = .int
    var idKey: String = "id"
    var queryLogger: QueryLogger?

    var testClosure: (Schema) -> ()
    init(testClosure: @escaping (Schema) -> ()) {
        self.testClosure = testClosure
    }
    
    public func makeConnection(_ type: ConnectionType) throws -> Connection {
        return TestSchemaConnection(driver: self)
    }
}

class TestSchemaConnection: Connection {
    public var isClosed: Bool = false
    var queryLogger: QueryLogger?
    
    var driver: TestSchemaDriver
    
    init(driver: TestSchemaDriver) {
        self.driver = driver
    }
    
    @discardableResult
    func query<T>(_ query: RawOr<Query<T>>) throws -> Node { return .null }


    func schema(_ schema: Schema) throws {
        driver.testClosure(schema)
    }
}
