import Async

// MARK: Internal

extension EventLoop {
    /// This worker's database.
    var databases: Databases? {
        get { return extend["fluent:databases"] as? Databases }
        set { extend["fluent:databases"] = newValue }
    }

    /// Returns this worker's database if one
    /// exists or throws an error.
    func requireDatabase(id: DatabaseIdentifier) throws -> Database {
        guard let database = databases?.storage[id] else {
            throw "Database on worker required"
        }

        return database
    }

    /// This's worker's connection pool.
    func getConnectionPool(
        database id: DatabaseIdentifier
    ) -> DatabaseConnectionPool? {
        guard let database = databases?.storage[id] else {
            return nil
        }

        if let existing = extend["fluent:connection-pool:\(id)"] as? DatabaseConnectionPool {
            return existing
        } else {
            let new = database.makeConnectionPool(max: 2, on: self)
            extend["fluent:connection-pool:\(id)"] = new
            return new
        }
    }

    /// Returns this worker's connection pool if one
    /// exists or throws an error.
    func requireConnectionPool(
        database: DatabaseIdentifier
    ) throws -> DatabaseConnectionPool {
        guard let connectionPool = getConnectionPool(database: database) else {
            throw "Connection pool on worker required"
        }

        return connectionPool
    }
}
