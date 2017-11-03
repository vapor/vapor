import Async
import Fluent
import FluentSQL
import SQLite

extension SQLiteConnection: SchemaSupporting {
    /// See SchemaExecutor.execute()
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        let schemaQuery = schema.makeSchemaQuery(delegate: self)

        let string = SQLiteSQLSerializer()
            .serialize(schema: schemaQuery)

        return makeQuery(string).execute()
    }
}

extension SQLiteConnection: SchemaDelegate {
    /// See SchemaDelegate.convertToDataType()
    public func convertToDataType(_ type: SchemaFieldType) -> String {
        switch type {
        case .string: return "TEXT"
        case .int: return "INTEGER"
        case .double, .date: return "REAL"
        case .data: return "BLOB"
        case .custom(let custom): return custom
        }
    }
}
