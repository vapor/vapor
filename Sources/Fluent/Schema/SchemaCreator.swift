import Async

/// Creates schemas.
public final class SchemaCreator<M: Model>: SchemaBuilder {
    public typealias ModelType = M
    public var schema: DatabaseSchema
    public let executor: SchemaExecutor

    public init(
        _ type: M.Type = M.self,
        on executor: SchemaExecutor
    ) {
        schema = DatabaseSchema(entity: M.entity)
        self.executor = executor
    }
}
