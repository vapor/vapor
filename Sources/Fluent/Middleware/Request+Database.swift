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

    public func database(
        id database: DatabaseIdentifier = .default
    ) -> Future<DatabaseConnection> {
        let promise = Promise(DatabaseConnection.self)

        if let currentConnection = getCurrentConnection(database: database) {
            currentConnection.chain(to: promise)
        } else {
            do {
                let pool = try requireWorker()
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
