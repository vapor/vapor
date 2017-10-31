import Async
import Fluent
import SQLite
import XCTest

final class SchemaTests: XCTestCase {
    func testCreate() throws {
        var schema = DatabaseSchema(entity: "users")
        schema.action = .create

        let name = Field(name: "name", type: .string)
        schema.addFields.append(name)

        let age = Field(name: "age", type: .int)
        schema.addFields.append(age)

        let conn = try SQLiteDatabase.makeTestConnection()
        try conn.execute(schema: schema).blockingAwait()
    }

    func testUpdate() throws {
        var schema = DatabaseSchema(entity: "users")
        schema.action = .create

        let name = Field(name: "name", type: .string)
        schema.addFields.append(name)

        let age = Field(name: "age", type: .int)
        schema.addFields.append(age)

        let conn = try! SQLiteDatabase.makeTestConnection()
        try conn.execute(schema: schema).blockingAwait()

        var change = DatabaseSchema(entity: "users")
        change.action = .update
        let bio = Field(name: "bio", type: .string, isOptional: true)
        change.addFields.append(bio)
        try! conn.execute(schema: change).blockingAwait()
    }

    func testDelete() throws {
        var schema = DatabaseSchema(entity: "users")
        schema.action = .create

        let name = Field(name: "name", type: .string)
        schema.addFields.append(name)

        let age = Field(name: "age", type: .int)
        schema.addFields.append(age)

        let conn = try SQLiteDatabase.makeTestConnection()
        try conn.execute(schema: schema).blockingAwait()

        var delete = DatabaseSchema(entity: "users")
        delete.action = .delete
        try conn.execute(schema: delete).blockingAwait()
    }

    func testError() throws {
        var delete = DatabaseSchema(entity: "users")
        delete.action = .delete

        let conn = try SQLiteDatabase.makeTestConnection()
        do {
            try conn.execute(schema: delete).blockingAwait()
            XCTFail("no error thrown")
        } catch {
            //
        }
    }

    static let allTests = [
        ("testCreate", testCreate),
        ("testUpdate", testUpdate),
        ("testDelete", testDelete),
        ("testError", testError),
    ]
}

