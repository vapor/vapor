import CSQLite
import Dispatch

/// SQlite connection. Use this to create statements that can be executed.
public final class SQLiteConnection {
    public typealias Raw = OpaquePointer
    public var raw: Raw

    /// the queue statement's will dispatch stream output to.
    public let queue: DispatchQueue

    /// serial background queue to perform all calls to SQLite C API on.
    /// this must be a serial queue since the SQLITE_OPEN_NOMUTEX does not
    /// support using a single database connection across multiple threads.
    internal let background: DispatchQueue

    /// Opens a connection to the SQLite database at a given path.
    /// If the database does not already exist, it will be created.
    ///
    /// The supplied DispatchQueue will be used to dispatch output stream calls.
    /// Make sure to supply the event loop to this parameter so you get called back
    /// on the appropriate thread.
    public init(database: SQLiteDatabase, queue: DispatchQueue) throws {
        let options = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX
        var raw: Raw?

        guard sqlite3_open_v2(database.storage.path, &raw, options, nil) == SQLITE_OK else {
            throw SQLiteError(problem: .error, reason: "Could not open database.")
        }

        guard let r = raw else {
            throw SQLiteError(problem: .error, reason: "Unexpected nil database.")
        }

        self.raw = r
        self.queue = queue
        self.background = DispatchQueue(label: "sqlite.connection.\(r)")
    }

    /// Returns the last error message, if one exists.
    var errorMessage: String? {
        guard let raw = sqlite3_errmsg(raw) else {
            return nil
        }

        return String(cString: raw)
    }

    /// Creates a new SQLite statement.
    public func query(_ query: String) throws -> SQLiteQuery {
        return try SQLiteQuery(statement: query, database: self)
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
