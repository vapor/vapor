import Core

extension Worker {
    /// This worker's database.
    var database: Database? {
        get { return extend["fluent:database"] as? Database }
        set { extend["fluent:database"] = newValue }
    }

    /// Returns this worker's database if one
    /// exists or throws an error.
    func requireDatabase() throws -> Database {
        guard let database = self.database else {
            throw "Database on worker required"
        }

        return database
    }

    /// This's worker's connection pool.
    var connectionPool: DatabaseConnectionPool? {
        guard let database = self.database else {
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
    func requireConnectionPool() throws -> DatabaseConnectionPool {
        guard let connectionPool = self.connectionPool else {
            throw "Connection pool on worker required"
        }

        return connectionPool
    }
}
