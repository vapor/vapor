import Async
import HTTP

extension Request {
    /// Returns a future database connection for the
    /// supplied database identifier if one can be fetched.
    /// The database connection will be cached on this worker.
    /// The same database connection will always be returned for
    /// a given worker.
    public func database<Database>(
        id database: DatabaseIdentifier<Database>
    ) -> Future<Database.Connection> {
        let promise = Promise(Database.Connection.self)

        if let currentConnection = getCurrentConnection(database: database) {
            currentConnection.chain(to: promise)
        } else {
            do {
                let pool = try eventLoop
                    .requireConnectionPool(database: database)
                let conn = pool.requestConnection()
                setCurrentConnection(to: conn, database: database)
                conn.chain(to: promise)
            } catch {
                promise.fail(error)
            }
        }

        return promise.future
    }
}

// MARK: Internal

extension Request {
    /// The current connection for this request.
    /// Note: This is a Future as the connection may not yet
    /// be available. However, we want all queries for
    /// this request to use the _same_ connection when it
    /// becomes available.
    func getCurrentConnection<Database>(
        database: DatabaseIdentifier<Database>
    ) -> Future<Database.Connection>? {
        return extend["fluent:current-connection:\(database.uid)"] as? Future<Database.Connection>
    }

    func setCurrentConnection<Database>(
        to connection: Future<Database.Connection>?,
        database: DatabaseIdentifier<Database>
    ) {
        extend["fluent:current-connection:\(database.uid)"] = connection
    }


    /// Releases the current connection for this request
    /// if one exists.
    func releaseCurrentConnection<Database>(
        database: DatabaseIdentifier<Database>
    ) throws {
        guard let current = getCurrentConnection(database: database) else {
            return
        }

        let pool = try eventLoop
            .requireConnectionPool(database: database)

        current.then { conn in
            pool.releaseConnection(conn)
            self.setCurrentConnection(to: nil, database: database)
        }.catch { err in
            print("could not release connection")
        }
    }
}
