import Async
import Fluent
import FluentSQL
import SQLite

extension SQLiteConnection: SchemaSupporting, ReferenceSupporting {
    /// See SchemaExecutor.execute()
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        let schemaQuery = schema.makeSchemaQuery(delegate: self)

        let string = SQLiteSQLSerializer()
            .serialize(schema: schemaQuery)

        return makeQuery(string).execute()
    }

    /// ReferenceSupporting.enableReferences
    public func enableReferences() -> Future<Void> {
        return makeQuery("PRAGMA foreign_keys = ON;").execute()
    }

    /// ReferenceSupporting.disableReferences
    public func disableReferences() -> Future<Void> {
        return makeQuery("PRAGMA foreign_keys = OFF;").execute()
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
