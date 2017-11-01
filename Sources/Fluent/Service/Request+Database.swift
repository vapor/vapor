import Async
import Service

extension Worker where Self: HasContainer {
    /// Returns a future database connection for the
    /// supplied database identifier if one can be fetched.
    /// The database connection will be cached on this worker.
    /// The same database connection will always be returned for
    /// a given worker.
    public func database<Database, T>(
        _ database: DatabaseIdentifier<Database>,
        closure: @escaping (Database.Connection) throws -> Future<T>
    ) -> Future<T> {
        return then {
            let pool: DatabaseConnectionPool<Database>

            /// this is the first attempt to connect to this
            /// db for this request
            if let existing = self.eventLoop.getConnectionPool(database: database) {
                pool = existing
            } else {
                if let container = self.container {
                    pool = try self.eventLoop.makeConnectionPool(
                        database: database,
                        using: container.make(Databases.self, for: Self.self)
                    )
                } else {
                    throw "no container to create databases for connection pools"
                }
            }

            /// request a connection from the pool
            return pool.requestConnection().then { conn in
                return try closure(conn).map { res in
                    pool.releaseConnection(conn)
                    return res
                }
            }
        }
    }
}
