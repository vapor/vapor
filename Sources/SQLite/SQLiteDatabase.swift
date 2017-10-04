import Dispatch

/// Available SQLite storage methods.
public enum Storage {
    case memory
    case file(path: String)

    internal var path: String {
        switch self {
        case .memory:
            return ":memory:"
        case .file(let path):
            return path
        }
    }
}

/// SQlite database. Used to make connections.
public final class SQLiteDatabase {
    /// The path to the SQLite file.
    public let storage: Storage

    /// Create a new SQLite database.
    public init(storage: Storage) {
        self.storage = storage
    }

    /// Creates a new connection on the supplied queue.
    public func makeConnection(on queue: DispatchQueue) throws -> SQLiteConnection {
        return try SQLiteConnection(database: self, queue: queue)
    }

    /// Make a connection pool for this database.
    public func makeConnectionPool(max: UInt, on queue: DispatchQueue) -> SQLiteConnectionPool {
        return SQLiteConnectionPool(max: max, database: self, queue: queue)
    }
}
