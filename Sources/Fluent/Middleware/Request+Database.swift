import Async
import HTTP

extension Request {
    /// The current connection for this request.
    /// Note: This is a Future as the connection may not yet
    /// be available. However, we want all queries for
    /// this request to use the _same_ connection when it
    /// becomes available.
    func getCurrentConnection(
        forDatabaseNamed databaseName: String
    ) -> Future<DatabaseConnection>? {
        return extend["fluent:current-connection:\(databaseName)"] as? Future<DatabaseConnection>
    }

    func setCurrentConnection(
        to connection: Future<DatabaseConnection>?,
        forDatabaseNamed databaseName: String
    ) {
        extend["fluent:current-connection:\(databaseName)"] = connection
    }


    /// Releases the current connection for this request
    /// if one exists.
    func releaseCurrentConnection(
        forDatabaseNamed databaseName: String = .defaultDatabaseName
    ) throws {
        guard let current = getCurrentConnection(forDatabaseNamed: databaseName) else {
            return
        }

        let pool = try requireWorker()
            .requireConnectionPool(forDatabaseNamed: databaseName)

        current.then { conn in
            pool.releaseConnection(conn)
            self.setCurrentConnection(to: nil, forDatabaseNamed: databaseName)
        }.catch { err in
            print("could not release connection")
        }
    }

    /// Creates a database query using this request's
    /// current connection.
    ///
    /// If this request does not have a connection,
    /// a new connection will be requested from the worker's
    /// connection pool and cached to the request.
    ///
    /// Subsequent calls to this function will use the same connection.
    public func query<M>(
        _ modelType: M.Type = M.self,
        database: String = .defaultDatabaseName
    ) throws -> QueryBuilder<M> {
        if let currentConnection = getCurrentConnection(forDatabaseNamed: database) {
            return QueryBuilder(on: currentConnection)
        } else {
            let pool = try requireWorker()
                .requireConnectionPool(forDatabaseNamed: database)
            let conn = pool.requestConnection()
            setCurrentConnection(to: conn, forDatabaseNamed: database)
            return QueryBuilder(on: conn)
        }
    }
}
