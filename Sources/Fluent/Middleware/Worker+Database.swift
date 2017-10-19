import Async

extension String {
    /// Default database name.
    public static var defaultDatabaseName: String {
        return "default"
    }
}

extension Worker {
    /// This worker's database.
    func getDatabase(named name: String = .defaultDatabaseName) -> Database? {
        return extend["fluent:database:\(name)"] as? Database
    }

    /// Sets this worker's database.
    func setDatabase(
        named name: String = "default",
        to database: Database?
    ) {
        extend["fluent:database:\(name)"] = database
    }

    /// Returns this worker's database if one
    /// exists or throws an error.
    func requireDatabase(
        named name: String = .defaultDatabaseName
    ) throws -> Database {
        guard let database = getDatabase(named: name) else {
            throw "Database on worker required"
        }

        return database
    }

    /// This's worker's connection pool.
    func getConnectionPool(
        databaseName: String = .defaultDatabaseName
    ) -> DatabaseConnectionPool? {
        guard let database = getDatabase(named: databaseName) else {
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
        databaseName: String = .defaultDatabaseName
    ) throws -> DatabaseConnectionPool {
        guard let connectionPool = getConnectionPool(databaseName: databaseName) else {
            throw "Connection pool on worker required"
        }

        return connectionPool
    }
}
