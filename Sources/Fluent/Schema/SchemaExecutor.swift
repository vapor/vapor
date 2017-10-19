import Async

public protocol SchemaExecutor {
    /// Executes the supplied schema on the database connection.
    func execute(schema: DatabaseSchema) -> Future<Void>
}
