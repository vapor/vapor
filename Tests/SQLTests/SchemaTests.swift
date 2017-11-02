import SQL
import XCTest

final class SchemaTests: XCTestCase {
    func testCreate() {
        var columns: [SchemaColumn] = []

        let id = SchemaColumn(name: "id", dataType: .custom("UUID"), isPrimaryKey: true)
        columns.append(id)

        let name = SchemaColumn(name: "name", dataType: .custom("STRING"))
        columns.append(name)

        let age = SchemaColumn(name: "age", dataType: .custom("INT"))
        columns.append(age)

        let create = SchemaQuery(statement: .create(columns: columns), table: "users")
        XCTAssertEqual(
            GeneralSQLSerializer.shared.serialize(schema: create),
            "CREATE TABLE `users` (`id` UUID PRIMARY KEY, `name` STRING NOT NULL, `age` INT NOT NULL)"
        )
    }
}

