import Async

// MARK: Internal

/// Connection pools can be shared among event loops
/// without requiring thread safety.
extension EventLoop {
    /// This worker's database.
    var databases: Databases? {
        get { return extend["fluent:databases"] as? Databases }
        set { extend["fluent:databases"] = newValue }
    }

    /// Returns this worker's database if one
    /// exists or throws an error.
    func requireDatabase<Database>(
        id: DatabaseIdentifier<Database>
    ) throws -> Database {
        guard let database = databases?.storage[id.uid] as? Database else {
            throw "Database on worker required"
        }

        return database
    }

    /// This's worker's connection pool.
    func getConnectionPool<Database>(
        database id: DatabaseIdentifier<Database>
    ) -> DatabaseConnectionPool<Database>? {
        guard let database = databases?.storage[id.uid] as? Database else {
            return nil
        }

        if let existing = extend["fluent:connection-pool:\(id)"] as? DatabaseConnectionPool<Database> {
            return existing
        } else {
            let new = database.makeConnectionPool(max: 2, on: self)
            extend["fluent:connection-pool:\(id)"] = new
            return new
        }
    }

    /// Returns this worker's connection pool if one
    /// exists or throws an error.
    func requireConnectionPool<Database>(
        database: DatabaseIdentifier<Database>
    ) throws -> DatabaseConnectionPool<Database> {
        guard let connectionPool = getConnectionPool(database: database) else {
            throw "Connection pool on worker required"
        }

        return connectionPool
    }
}
