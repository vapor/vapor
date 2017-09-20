import XCTest
@testable import Fluent

class SQLiteTests: XCTestCase {
    func testMultipleColumnModify() throws {
        let memory = try SQLiteDriver(path: ":memory:")
        let database = Database(memory)

        let create = Query<User>(database)
        let id = Field(name: "id", type: .string(length: nil))
        create.action = .schema(.create(
            fields: [.some(id)],
            foreignKeys: []
        ))
        try memory.query(create)

        let modify = Query<User>(database)
        let foo = Field(name: "foo", type: .string(length: nil))
        modify.action = .schema(.modify(
            fields: [.some(foo), .some(foo)],
            foreignKeys: [],
            deleteFields: [],
            deleteForeignKeys: []
        ))
        do {
            try memory.query(modify)
            XCTFail("Multiple add/remove columns should have thrown")
        } catch SQLiteDriverError.unsupported {
            // pass
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testBlobColumnType() throws {
        final class BlobModel: Entity {
            let storage = Storage()

            var data: Blob

            init(data: [UInt8]) {
                self.data = Blob(bytes: data)
            }

            init(row: Row) throws {
                data = try row.get("data")
            }

            func makeRow() throws -> Row {
                var row = Row()
                try row.set("data", Node.bytes(data.bytes))
                return row
            }
        }

        let memory = try SQLiteDriver(path: ":memory:")
        let database = Database(memory)
        BlobModel.database = database

        try database.create(BlobModel.self) { builder in
            builder.id()
            builder.bytes("data")
        }

        let data: [UInt8] = [0, 1, 2, 3]
        let entity = BlobModel(data: data)
        try entity.save()

        guard let fetchedEntity = try BlobModel.all().first else {
            XCTFail("Entity not saved")
            return
        }

        XCTAssertEqual(fetchedEntity.data.bytes, data)
    }

    static let allTests = [
        ("testMultipleColumnModify", testMultipleColumnModify),
        ("testBlobColumnType", testBlobColumnType),
    ]
}
