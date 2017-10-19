import Async

public protocol SchemaBuilder: class {
    /// The associated model type.
    associatedtype ModelType: Model

    /// The schema being built.
    var schema: DatabaseSchema { get set }

    /// The connection this schema builder will execute on.
    var executor: Future<SchemaExecutor> { get }
}

extension SchemaBuilder {
    /// Adds a string type field.
    public func string(_ name: String) {
        let field = Field(name: name, type: .string)
        schema.addFields.append(field)
    }
}

/// Creates schemas.
public final class SchemaCreator<M: Model>: SchemaBuilder {
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
}

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
