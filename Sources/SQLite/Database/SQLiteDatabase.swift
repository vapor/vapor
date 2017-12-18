import Async
import CSQLite
import Dispatch

/// SQlite database. Used to make connections.
public final class SQLiteDatabase {
    /// The path to the SQLite file.
    public let storage: SQLiteStorage

    /// If set, query logs will be sent to the supplied logger.
    public var logger: SQLiteLogger?

    /// Create a new SQLite database.
    public init(storage: SQLiteStorage) {
        self.storage = storage
    }

    /// Opens a connection to the SQLite database at a given path.
    /// If the database does not already exist, it will be created.
    ///
    /// The supplied DispatchQueue will be used to dispatch output stream calls.
    /// Make sure to supply the event loop to this parameter so you get called back
    /// on the appropriate thread.
    public func makeConnection(
        on Worker: Worker
    ) -> Future<SQLiteConnection> {
        return Future {
            let options = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX
            var raw: SQLiteConnection.Raw?
            guard sqlite3_open_v2(self.storage.path, &raw, options, nil) == SQLITE_OK else {
                throw SQLiteError(problem: .error, reason: "Could not open database.")
            }

            guard let r = raw else {
                throw SQLiteError(problem: .error, reason: "Unexpected nil database.")
            }

            return Future(SQLiteConnection(raw: r, database: self))
        }
    }
}
