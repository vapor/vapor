import Dispatch

/// SQlite database. Used to make connections.
public final class Database {
    /// The path to the SQLite file.
    public let path: String

    /// Create a new SQLite database.
    public init(path: String) {
        self.path = path
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
