import SQL
import XCTest

final class SchemaTests: XCTestCase {
    func testCreate() {
        var create = SchemaQuery(statement: .create, table: "users")

        let id = SchemaColumn(name: "id", dataType: "UUID", isPrimaryKey: true)
        create.columns.append(id)

        let name = SchemaColumn(name: "name", dataType: "STRING")
        create.columns.append(name)

        let age = SchemaColumn(name: "age", dataType: "INT")
        create.columns.append(age)

        XCTAssertEqual(
            GeneralSQLSerializer.shared.serialize(schema: create),
            "CREATE TABLE `users` (`id` UUID PRIMARY KEY, `name` STRING NOT NULL, `age` INT NOT NULL)"
        )
    }
}

