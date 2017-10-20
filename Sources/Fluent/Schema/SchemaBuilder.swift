import Async

public protocol SchemaBuilder: class {
    /// The associated model type.
    associatedtype ModelType: Model

    /// The schema being built.
    var schema: DatabaseSchema { get set }

    /// The connection this schema builder will execute on.
    var executor: Future<SchemaExecutor> { get }

    /// Create a new schema builder.
    init(_ type: ModelType.Type, on executor: Future<SchemaExecutor>)
}

// MARK: Convenience

extension SchemaBuilder {
    public init<S: SchemaExecutor>(
        _ type: ModelType.Type = ModelType.self,
        on executor: S
    ) {
        self.init(ModelType.self, on: Future(executor))
    }
}
