import Async

/// Helps you create and execute a database schema.
public protocol SchemaBuilder: class {
    /// The associated model type.
    associatedtype ModelType: Model

    /// The schema being built.
    var schema: DatabaseSchema { get set }

    /// The connection this schema builder will execute on.
    var executor: SchemaExecutor { get }

    /// Create a new schema builder.
    init(_ type: ModelType.Type, on executor: SchemaExecutor)
}
