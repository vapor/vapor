import Async

/// Capable of executing a database schema query.
public protocol SchemaExecutor {
    /// Executes the supplied schema on the database connection.
    func execute(schema: DatabaseSchema) -> Future<Void>
}

// MARK: Convenience

extension SchemaExecutor {
    /// Closure for accepting a schema creator.
    public typealias CreateClosure<M: Model> = (SchemaCreator<M>) -> ()

    /// Convenience for creating a closure that accepts a schema creator
    /// for the supplied model type on this schema executor.
    public func create<M>(_ type: M.Type, closure: CreateClosure<M>) -> Future<Void> {
        let creator = SchemaCreator(M.self, on: self)
        closure(creator)
        return execute(schema: creator.schema)
    }

    /// Closure for accepting a schema updater.
    public typealias UpdateClosure<M: Model> = (SchemaUpdater<M>) -> ()

    /// Convenience for creating a closure that accepts a schema updater
    /// for the supplied model type on this schema executor.
    public func update<M>(_ type: M.Type, closure: UpdateClosure<M>) -> Future<Void> {
        let updater = SchemaUpdater(M.self, on: self)
        closure(updater)
        return execute(schema: updater.schema)
    }

    /// Convenience for deleting the schema for the supplied model type.
    public func delete<M: Model>(_ type: M.Type) -> Future<Void> {
        var schema = DatabaseSchema(entity: M.entity)
        schema.action = .delete
        return execute(schema: schema)
    }
}
