import Async
import Fluent
import FluentSQL
import SQLite

extension SQLiteConnection: SchemaExecutor {
    /// See SchemaExecutor.execute()
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        let schemaQuery = schema.makeSchemaQuery()
        let string = SQLiteSQLSerializer()
            .serialize(schema: schemaQuery)

        return makeQuery(string).execute()
    }
}
