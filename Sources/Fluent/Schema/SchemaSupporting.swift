import Async

/// Capable of executing a database schema query.
public protocol SchemaSupporting: Connection {
    /// Executes the supplied schema on the database connection.
    func execute(schema: DatabaseSchema) -> Future<Void>
}

// MARK: Convenience

extension SchemaSupporting {
    /// Closure for accepting a schema creator.
    public typealias CreateClosure<Model: Fluent.Model> = (SchemaCreator<Model, Self>) throws -> ()

    /// Convenience for creating a closure that accepts a schema creator
    /// for the supplied model type on this schema executor.
    public func create<Model>(_ model: Model.Type, closure: @escaping CreateClosure<Model>) -> Future<Void> {
        let creator = SchemaCreator(Model.self, on: self)
        return then {
            try closure(creator)
            return self.execute(schema: creator.schema)
        }
    }

    /// Closure for accepting a schema updater.
    public typealias UpdateClosure<Model: Fluent.Model> = (SchemaUpdater<Model, Self>) throws -> ()

    /// Convenience for creating a closure that accepts a schema updater
    /// for the supplied model type on this schema executor.
    public func update<Model>(_ model: Model.Type, closure: @escaping UpdateClosure<Model>) -> Future<Void> {
        let updater = SchemaUpdater(Model.self, on: self)
        return then {
            try closure(updater)
            return self.execute(schema: updater.schema)
        }
    }

    /// Convenience for deleting the schema for the supplied model type.
    public func delete<Model: Fluent.Model>(_ model: Model.Type) -> Future<Void> {
        var schema = DatabaseSchema(entity: Model.entity)
        schema.action = .delete
        return execute(schema: schema)
    }
}
