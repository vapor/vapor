import Async

/// Updates schemas, capable of deleting fields.
public final class SchemaUpdater<
    Model: Fluent.Model,
    Connection: SchemaSupporting
>: SchemaBuilder {
    /// See SchemaBuilder.schema
    public var schema: DatabaseSchema

    /// See SchemaBuilder.executor
    public let connection: Connection

    /// Create a new schema updater.
    public init(
        _ type: Model.Type = Model.self,
        on executor: Connection
    ) {
        schema = DatabaseSchema(entity: Model.entity)
        self.connection = executor
    }

    /// Deletes the field with the supplied name.
    public func delete(_ name: String) {
        schema.removeFields.append(name)
    }
}

