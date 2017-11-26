import Async

/// Helps you create and execute a database schema.
public protocol SchemaBuilder: class {
    /// The associated model type.
    associatedtype Model: Fluent.Model

    /// The associated connection type (must support schemas!)
    associatedtype Connection: SchemaSupporting

    /// The schema being built.
    var schema: DatabaseSchema { get set }

    /// The connection this schema builder will execute on.
    var connection: Connection { get }

    /// Create a new schema builder.
    init(_ model: Model.Type, on connection: Connection)
}
