import Async
import Fluent
import SQL
import SQLite

extension SQLiteConnection: SchemaExecutor {
    /// See SchemaExecutor.execute()
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        let schemaStatement: SchemaStatement

        switch schema.action {
        case .create:
            schemaStatement = .create(columns: schema.addFields.map { $0.column })
        case .update:
            guard schema.removeFields.count == 0 else {
                return Future(error: "SQLite does not support deleting columns")
            }

            schemaStatement = .alter(
                columns: schema.addFields.map { $0.column },
                deleteColumns: schema.removeFields
            )
        case .delete:
            schemaStatement = .drop
        }

        let schemaQuery = SchemaQuery(statement: schemaStatement, table: schema.entity)
        let string = SQLiteSQLSerializer()
            .serialize(query: .schema(schemaQuery))

        return makeQuery(string).execute()
    }
}

// MARK: private

extension SchemaField {
    fileprivate var column: SchemaColumn {
        return SchemaColumn(
            name: name,
            dataType: type.dataType,
            isNotNull: !isOptional,
            isPrimaryKey: isIdentifier
        )
    }
}

extension SchemaFieldType {
    fileprivate var dataType: String {
        switch self {
        case .string:
            return "TEXT"
        case .int:
            return "INTEGER"
        case .double:
            return "REAL"
        case .data:
            return "BLOB"
        case .date:
            return "INTEGER"
        case .custom(let custom):
            return custom
        }
    }
}
