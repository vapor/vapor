import Async
import CSQLite
import Dispatch

/// SQlite connection. Use this to create statements that can be executed.
public final class SQLiteConnection {
    public typealias Raw = OpaquePointer
    public var raw: Raw

    /// Reference to the database that created this connection.
    public let database: SQLiteDatabase

    /// This connection's eventloop.
    public let eventLoop: EventLoop

    /// Returns the last error message, if one exists.
    var errorMessage: String? {
        guard let raw = sqlite3_errmsg(raw) else {
            return nil
        }

        return String(cString: raw)
    }

    /// Create a new SQLite conncetion.
    internal init(
        raw: Raw,
        database: SQLiteDatabase,
        on worker: Worker
    ) {
        self.raw = raw
        self.database = database
        self.eventLoop = worker.eventLoop
    }

    /// Returns an identifier for the last inserted row.
    public var lastAutoincrementID: Int? {
        let id = sqlite3_last_insert_rowid(raw)
        return Int(id)
    }

    /// Closes the database connection.
    public func close() {
        sqlite3_close(raw)
    }

    /// Convenience for creating a SQLite query.
    public func query(string: String) -> SQLiteQuery {
        return SQLiteQuery(string: string, connection: self)
    }

    /// Closes the database when deinitialized.
    deinit {
        close()
    }
}
