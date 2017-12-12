import Async

/// Declares a database migration.
public protocol Migration {
    /// The type of database this migration can run on.
    /// Migrations require a query executor to work correctly
    /// as they must be able to query the MigrationLog model.
    associatedtype Database: Fluent.Database

    /// Runs this migration's changes on the database.
    /// This is usually creating a table, or altering an existing one.
    static func prepare(on connection: Database.Connection) -> Completable

    /// Reverts this migration's changes on the database.
    /// This is usually dropping a created table. If it is not possible
    /// to revert the changes from this migration, complete the future
    /// with an error.
    static func revert(on connection: Database.Connection) -> Completable
}
