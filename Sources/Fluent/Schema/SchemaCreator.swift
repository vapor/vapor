import Async

/// A schema builder specifically for creating
/// new tables and collections.
public final class SchemaCreator<
    Model: Fluent.Model,
    Connection: SchemaSupporting
>: SchemaBuilder {
    /// See SchemaBuilder.schema
    public var schema: DatabaseSchema

    /// See SchemaBuilder.executor
    public let connection: Connection

    /// Create a new schema creator.
    public init(
        _ type: Model.Type = Model.self,
        on connection: Connection
    ) {
        schema = DatabaseSchema(entity: Model.entity)
        self.connection = connection
    }
}
