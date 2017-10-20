import Async

public protocol SchemaExecutor {
    /// Executes the supplied schema on the database connection.
    func execute(schema: DatabaseSchema) -> Future<Void>
}

// Convenience

extension SchemaExecutor {
    public typealias CreateClosure<M: Model> = (SchemaCreator<M>) -> ()
    public typealias UpdateClosure<M: Model> = (SchemaUpdater<M>) -> ()

    public func create<M>(_ type: M.Type, closure: CreateClosure<M>) -> Future<Void> {
        let creator = SchemaCreator(M.self, on: self)
        closure(creator)
        return execute(schema: creator.schema)
    }

    public func update<M>(_ type: M.Type, closure: UpdateClosure<M>) -> Future<Void> {
        let updater = SchemaUpdater(M.self, on: self)
        closure(updater)
        return execute(schema: updater.schema)
    }

    public func delete<M: Model>(_ type: M.Type) -> Future<Void> {
        var schema = DatabaseSchema(entity: M.entity)
        schema.action = .delete
        return execute(schema: schema)
    }
}
