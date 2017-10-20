import Async
import HTTP

extension Request {
    /// The current connection for this request.
    /// Note: This is a Future as the connection may not yet
    /// be available. However, we want all queries for
    /// this request to use the _same_ connection when it
    /// becomes available.
    func getCurrentConnection(
        database: DatabaseIdentifier
    ) -> Future<DatabaseConnection>? {
        return extend["fluent:current-connection:\(database.uid)"] as? Future<DatabaseConnection>
    }

    func setCurrentConnection(
        to connection: Future<DatabaseConnection>?,
        database: DatabaseIdentifier
    ) {
        extend["fluent:current-connection:\(database.uid)"] = connection
    }


    /// Releases the current connection for this request
    /// if one exists.
    func releaseCurrentConnection(
        database: DatabaseIdentifier
    ) throws {
        guard let current = getCurrentConnection(database: database) else {
            return
        }

        let pool = try requireWorker()
            .requireConnectionPool(database: database)

        current.then { conn in
            pool.releaseConnection(conn)
            self.setCurrentConnection(to: nil, database: database)
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
        database: DatabaseIdentifier = .main
    ) throws -> QueryBuilder<M> {
        if let currentConnection = getCurrentConnection(database: database) {
            return QueryBuilder(on: currentConnection)
        } else {
            let pool = try requireWorker()
                .requireConnectionPool(database: database)
            let conn = pool.requestConnection()
            setCurrentConnection(to: conn, database: database)
            return QueryBuilder(on: conn)
        }
    }
}
