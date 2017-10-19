/// Types conforming to this protocol can be used
/// as a Fluent database connection for executing queries.
public protocol DatabaseConnection: QueryExecutor, SchemaExecutor { }
