import SQL
import XCTest

final class SchemaTests: XCTestCase {
    func testCreate() {
        var columns: [SchemaColumn] = []

        let id = SchemaColumn(name: "id", dataType: "UUID", isPrimaryKey: true)
        columns.append(id)

        let name = SchemaColumn(name: "name", dataType: "STRING")
        columns.append(name)

        let age = SchemaColumn(name: "age", dataType: "INT")
        columns.append(age)

        let create = SchemaQuery(
            statement: .create(columns: columns, foreignKeys: []),
            table: "users"
        )
        XCTAssertEqual(
            GeneralSQLSerializer.shared.serialize(schema: create),
            "CREATE TABLE `users` (`id` UUID PRIMARY KEY, `name` STRING NOT NULL, `age` INT NOT NULL)"
        )
    }

    func testForeignKeys() {
        let columns = [
            SchemaColumn(name: "id", dataType: "UUID", isPrimaryKey: true),
            SchemaColumn(name: "name", dataType: "STRING"),
            SchemaColumn(name: "age", dataType: "INT"),
            SchemaColumn(name: "role_id", dataType: "UUID", isNotNull: false)
        ]

        let foreignKeys = [
            SchemaForeignKey(name: "", local: .init(name: "role_id"), foreign: .init(table: "roles", name: "id"), onUpdate: "NO ACTION", onDelete: "SET NULL")
        ]

        let create = SchemaQuery(
            statement: .create(columns: columns, foreignKeys: foreignKeys),
            table: "users"
        )
        XCTAssertEqual(
            GeneralSQLSerializer.shared.serialize(schema: create),
            "CREATE TABLE `users` (`id` UUID PRIMARY KEY, `name` STRING NOT NULL, `age` INT NOT NULL, `role_id` UUID, FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON UPDATE NO ACTION ON DELETE SET NULL)"
        )
    }
}

