import Async
import CSQLite
import Dispatch

/// SQlite connection. Use this to create statements that can be executed.
public final class SQLiteConnection {
    public typealias Raw = OpaquePointer
    public var raw: Raw

    /// Reference to the database that created this connection.
    public let database: SQLiteDatabase

    /// the queue statement's will dispatch stream output to.
    public let worker: Worker

    /// serial background queue to perform all calls to SQLite C API on.
    /// this must be a serial queue since the SQLITE_OPEN_NOMUTEX does not
    /// support using a single database connection across multiple threads.
    internal let background: DispatchQueue

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
        Worker: Worker,
        background: DispatchQueue,
        database: SQLiteDatabase
    ) {
        self.raw = raw
        self.Worker = Worker
        self.background = background
        self.database = database
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
