import Async

extension Worker {
    /// This worker's database.
    func getDatabase(id: DatabaseIdentifier) -> Database? {
        return extend["fluent:database:\(id.uid)"] as? Database
    }

    /// Sets this worker's database.
    func setDatabase(id: DatabaseIdentifier, to database: Database?) {
        extend["fluent:database:\(id.uid)"] = database
    }

    /// Returns this worker's database if one
    /// exists or throws an error.
    func requireDatabase(id: DatabaseIdentifier) throws -> Database {
        guard let database = getDatabase(id: id) else {
            throw "Database on worker required"
        }

        return database
    }

    /// This's worker's connection pool.
    func getConnectionPool(
        database: DatabaseIdentifier
    ) -> DatabaseConnectionPool? {
        guard let database = getDatabase(id: database) else {
            return nil
        }

        if let existing = extend["fluent:connection-pool"] as? DatabaseConnectionPool {
            return existing
        } else {
            let new = database.makeConnectionPool(max: 2, on: queue)
            extend["vapor:connection-pool"] = new
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
