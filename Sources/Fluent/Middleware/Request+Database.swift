import Async
import HTTP

extension Request {
    /// The current connection for this request.
    /// Note: This is a Future as the connection may not yet
    /// be available. However, we want all queries for
    /// this request to use the _same_ connection when it
    /// becomes available.
    var currentConnection: Future<DatabaseConnection>? {
        get { return extend["fluent:current-connection"] as? Future<DatabaseConnection> }
        set { extend["fluent:current-connection"] = newValue }
    }

    /// Releases the current connection for this request
    /// if one exists.
    func releaseCurrentConnection() throws {
        guard let current = currentConnection else {
            return
        }

        let pool = try requireWorker()
            .requireConnectionPool()

        current.then { conn in
            pool.releaseConnection(conn)
            self.currentConnection = nil
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
    public func query<M>(_ modelType: M.Type = M.self) throws -> QueryBuilder<M> {
        if let currentConnection = self.currentConnection {
            return QueryBuilder(on: currentConnection)
        } else {
            let pool = try requireWorker().requireConnectionPool()
            let conn = pool.requestConnection()
            currentConnection = conn
            return QueryBuilder(on: conn)
        }
    }
}
