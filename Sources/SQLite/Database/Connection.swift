import Async
import CSQLite
import Dispatch

/// SQlite connection. Use this to create statements that can be executed.
public final class SQLiteConnection {
    public typealias Raw = OpaquePointer
    public var raw: Raw

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
        worker: Worker,
        background: DispatchQueue
    ) {
        self.raw = raw
        self.worker = worker
        self.background = background
    }

    /// Returns an identifier for the last inserted row.
    public var lastId: Int? {
        let id = sqlite3_last_insert_rowid(raw)
        return Int(id)
    }

    /// Closes the database connection.
    public func close() {
        sqlite3_close(raw)
    }

    /// Closes the database when deinitialized.
    deinit {
        close()
    }
}
