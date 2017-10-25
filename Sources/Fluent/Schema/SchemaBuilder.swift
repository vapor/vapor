import Async

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

// MARK: Convenience - Fix w/ conditional conformance
extension Future: SchemaExecutor {
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        let promise = Promise(Void.self)

        if T.self is SchemaExecutor {
            self.then { result in
                let executor = result as! SchemaExecutor
                executor.execute(schema: schema)
                    .chain(to: promise)
            }.catch(promise.fail)
        } else {
            promise.fail("future not schema executor type")
        }

        return promise.future
    }
}
