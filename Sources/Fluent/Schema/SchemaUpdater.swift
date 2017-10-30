import Async

/// Updates schemas, capable of deleting fields.
public final class SchemaUpdater<M: Model>: SchemaBuilder {
    /// See SechemaBuilder.ModelType
    public typealias ModelType = M

    /// See SchemaBuilder.schema
    public var schema: DatabaseSchema

    /// See SchemaBuilder.executor
    public let executor: SchemaExecutor

    /// Create a new schema updater.
    public init(
        _ type: M.Type = M.self,
        on executor: SchemaExecutor
    ) {
        schema = DatabaseSchema(entity: M.entity)
        self.executor = executor
    }

    /// Deletes the field with the supplied name.
    public func delete(_ name: String) {
        schema.removeFields.append(name)
    }
}

