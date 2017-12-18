import Async
import Service
import Dispatch

/// Types conforming to this protocol can be used as
/// a database for Fluent connections and connection pools.
public protocol Database {
    /// This database's connection type.
    /// The connection should also know which
    /// type of database it belongs to.
    associatedtype Connection: Fluent.DatabaseConnection

    /// Creates a new database connection that will
    /// execute callbacks on the supplied dispatch queue.
    func makeConnection(
        from config: Connection.Config,
        on worker: Worker
    ) -> Future<Connection>
}

extension Database {
    /// Create a fluent connection pool for this database.
    public func makeConnectionPool(max: UInt, using config: Connection.Config, on worker: Worker) -> DatabaseConnectionPool<Self> {
        return DatabaseConnectionPool(max: max, database: self, using: config, on: worker)
    }
}
