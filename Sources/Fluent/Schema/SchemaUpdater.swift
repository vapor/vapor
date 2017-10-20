import Async

/// Updates schemas, capable of deleting fields.
public final class SchemaUpdater<M: Model>: SchemaBuilder {
    public typealias ModelType = M
    public var schema: DatabaseSchema
    public let executor: Future<SchemaExecutor>

    public init(
        _ type: M.Type = M.self,
        on executor: Future<SchemaExecutor>
        ) {
        schema = DatabaseSchema(entity: M.entity)
        self.executor = executor
    }

    public func delete(_ name: String) {
        schema.removeFields.append(name)
    }
}

