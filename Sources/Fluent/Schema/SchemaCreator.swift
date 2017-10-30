import Async

/// A schema builder specifically for creating
/// new tables and collections.
public final class SchemaCreator<M: Model>: SchemaBuilder {
    /// See SechemaBuilder.ModelType
    public typealias ModelType = M

    /// See SchemaBuilder.schema
    public var schema: DatabaseSchema

    /// See SchemaBuilder.executor
    public let executor: SchemaExecutor

    /// Create a new schema creator.
    public init(
        _ type: M.Type = M.self,
        on executor: SchemaExecutor
    ) {
        schema = DatabaseSchema(entity: M.entity)
        self.executor = executor
    }
}
