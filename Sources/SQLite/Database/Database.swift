import Dispatch

/// SQlite database. Used to make connections.
public final class SQLiteDatabase {
    /// The path to the SQLite file.
    public let storage: SQLiteStorage

    /// Create a new SQLite database.
    public init(storage: SQLiteStorage) {
        self.storage = storage
    }
}
