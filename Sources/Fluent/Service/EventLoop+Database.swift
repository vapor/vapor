import Async

// MARK: Internal

/// Connection pools can be shared among event loops
/// without requiring thread safety.
extension EventLoop {
    /// This's worker's connection pool.
    func getConnectionPool<Database>(
        database id: DatabaseIdentifier<Database>
    ) -> DatabaseConnectionPool<Database>? {
        return extend["fluent:connection-pool:\(id)"] as? DatabaseConnectionPool<Database>
    }

    func makeConnectionPool<Database>(
        database id: DatabaseIdentifier<Database>,
        using databases: Databases
    ) throws -> DatabaseConnectionPool<Database> {
        guard let database = databases.storage[id.uid] as? Database else {
            throw "no database with id '\(id)' configured"
        }

        let new = database.makeConnectionPool(max: 2, on: self)
        extend["fluent:connection-pool:\(id)"] = new
        return new
    }
}
