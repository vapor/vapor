import Dispatch

/// Database storage options.
public enum DatabaseStorage {
    case file(path: String)
    case memory

    internal var path: String {
        switch self {
        case .file(let path):
            return path
        case .memory:
            return ":memory:"
        }
    }
}

/// SQlite database. Used to make connections.
public final class Database {
    /// The path to the SQLite file.
    public let storage: DatabaseStorage

    /// Create a new SQLite database.
    public init(storage: DatabaseStorage = .memory) {
        self.storage = storage
    }

    /// Creates a new connection on the supplied queue.
    public func makeConnection(on queue: DispatchQueue) throws -> Connection {
        return try Connection(database: self, queue: queue)
    }

    /// Make a connection pool for this database.
    public func makeConnectionPool(max: UInt, on queue: DispatchQueue) -> ConnectionPool {
        return ConnectionPool(max: max, database: self, queue: queue)
    }
}
