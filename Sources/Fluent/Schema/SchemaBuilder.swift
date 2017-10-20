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
