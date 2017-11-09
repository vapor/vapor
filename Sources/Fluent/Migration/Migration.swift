import Async

/// Declares a database migration.
public protocol Migration {
    /// The type of database this migration can run on.
    /// Migrations require a query executor to work correctly
    /// as they must be able to query the MigrationLog model.
    associatedtype Database: Fluent.Database

    /// Runs this migration's changes on the database.
    /// This is usually creating a table, or altering an existing one.
    static func prepare(on connection: Database.Connection) -> Future<Void>

    /// Reverts this migration's changes on the database.
    /// This is usually dropping a created table. If it is not possible
    /// to revert the changes from this migration, complete the future
    /// with an error.
    static func revert(on connection: Database.Connection) -> Future<Void>
}

// MARK: Model

extension Migration where Self: Model, Database.Connection: SchemaSupporting {
    /// See Migration.prepare
    public static func prepare(on connection: Database.Connection) -> Future<Void> {
        return connection.create(self) { builder in
            for (key, field) in keyFieldMap {
                if let schema = key.type as? SchemaFieldTypeRepresentable.Type {
                    try builder.field(schema.makeSchemaFieldType(), field, isOptional: key.isOptional)
                } else {
                    throw "Type `\(key.type)` for field `\(Self.self).\(field.name)` does not conform to `SchemaFieldTypeRepresentable`."
                }
            }
        }
    }

    /// See Migration.revert
    public static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(self)
    }
}
