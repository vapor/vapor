import Async
import HTTP

extension Request {
    /// Returns a future database connection for the
    /// supplied database identifier if one can be fetched.
    /// The database connection will be cached on this worker.
    /// The same database connection will always be returned for
    /// a given worker.
    public func database<Database>(
        _ database: DatabaseIdentifier<Database>
    ) -> Future<Database.Connection> {
        let promise = Promise(Database.Connection.self)

        if let currentConnection = currentConnections[database.uid]?.connection as? Future<Database.Connection> {
            /// this request already has a connection
            /// for this db, use it
            currentConnection.chain(to: promise)
        } else {
            /// this is the first attempt to connect to this
            /// db for this request
            if let pool = eventLoop.getConnectionPool(database: database) {
                /// request a connection from the pool
                let conn = pool.requestConnection()

                /// create a struct that contains both this connection
                /// and the information to release it.
                let current = CurrentConnection(connection: conn) {
                    conn.then { conn in
                        pool.releaseConnection(conn)
                        self.currentConnections[database.uid] = nil
                    }.catch { err in
                        print("could not release connection: \(err)")
                    }
                }

                /// store this struct
                currentConnections[database.uid] = current

                /// done
                conn.chain(to: promise)
            } else {
                promise.fail("no connection pool for \(database)")
            }
        }

        return promise.future
    }

    /// Releases the database connection for the supplied
    /// database id if it is currently in-use.
    public func releaseDatabaseConnection<Database>(_ database: DatabaseIdentifier<Database>) {
        currentConnections[database.uid]?.release()
    }

    /// Releases all database connections.
    public func releaseDatabaseConnections() {
        for connection in currentConnections.values {
            connection.release()
        }
    }
}

// MARK: Private

extension Request {
    /// The current connections for this request.
    /// Note: This is a Future as the connection may not yet
    /// be available. However, we want all queries for
    /// this request to use the _same_ connection when it
    /// becomes available.
    fileprivate var currentConnections: [String: CurrentConnection] {
        get { return extend["fluent:current-connections"] as? [String: CurrentConnection] ?? [:] }
        set { extend["fluent:current-connections"] = newValue }
    }
}

/// Struct containing an in-use connection
fileprivate struct CurrentConnection {
    /// Store the connection here. This
    /// must be casted back to the desired connection type.
    let connection: Any

    /// Closure for releasing the connection.
    typealias ReleaseClosure = () -> ()

    /// Upon call, will release the connection.
    let release: ReleaseClosure

    /// Create a new CurrentConnection for the supplied connection
    /// and release callback.
    init(connection: Any, release: @escaping ReleaseClosure) {
        self.connection = connection
        self.release = release
    }
}
