import Async
import SQL
import SQLite

extension SQLiteConnection: SchemaExecutor {
    /// See SchemaExecutor.execute()
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        let promise = Promise(Void.self)

        let schemaStatement: SchemaStatement

        switch schema.action {
        case .create:
            schemaStatement = .create(columns: schema.addFields.map { $0.column })
        case .update:
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

        let sqliteQuery = SQLiteQuery(
            string: string,
            connection: self
        )
        sqliteQuery.execute().then {
            promise.complete()
        }.catch { err in
            promise.fail(err)
        }

        return promise.future
    }
}

// MARK: private

extension Field {
    fileprivate var column: SchemaColumn {
        return SchemaColumn(
            name: name,
            dataType: type.dataType,
            isNotNull: !isOptional,
            isPrimaryKey: isIdentifier
        )
    }
}

extension FieldType {
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
        case .custom(let custom):
            return custom
        }
    }
}
