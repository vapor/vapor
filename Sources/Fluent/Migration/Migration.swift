import Async

/// Declares a database migration.
public protocol Migration {
    /// Runs this migration's changes on the database.
    /// This is usually creating a table, or altering an existing one.
    static func prepare(_ database: DatabaseConnection) -> Future<Void>

    /// Reverts this migration's changes on the database.
    /// This is usually dropping a created table. If it is not possible
    /// to revert the changes from this migration, complete the future
    /// with an error.
    static func revert(_ database: DatabaseConnection) -> Future<Void>
}
