import Async
import Service

/// Create non-pooled connections that can be closed when done.
extension Container {
    /// Returns a future database connection for the
    /// supplied database identifier if one can be fetched.
    /// The database connection will be cached on this worker.
    /// The same database connection will always be returned for
    /// a given worker.
    public func withConnection<Database, F>(
        to database: DatabaseIdentifier<Database>,
        closure: @escaping (Database.Connection) throws -> F
    ) -> Future<F.Expectation> where F: FutureType {
        return makeConnection(to: database).then { conn in
            return try closure(conn).map { e in
                conn.close()
                return e
            }
        }
    }

    /// Requests a connection to the database.
    /// Call `.close` on the connection when you are finished.
    public func makeConnection<Database>(
        to database: DatabaseIdentifier<Database>
    ) -> Future<Database.Connection> {
        return then {
            let databases = try self.make(Databases.self, for: Self.self)

            guard let db = databases.storage[database.uid] as? Database else {
                throw "no database with id '\(database)' configured"
            }

            return db.makeConnection(on: self)
        }
    }
}

/// Ephemeral workers use connection pooling.
extension EphemeralContainer {
    /// Returns a future database connection for the
    /// supplied database identifier if one can be fetched.
    /// The database connection will be cached on this worker.
    /// The same database connection will always be returned for
    /// a given worker.
    public func withConnection<Database, F>(
        to database: DatabaseIdentifier<Database>,
        closure: @escaping (Database.Connection) throws -> F
    ) -> Future<F.Expectation> where F: FutureType {
        return then {
            let pool: DatabaseConnectionPool<Database>

            /// this is the first attempt to connect to this
            /// db for this request
            if let existing = self.eventLoop.getConnectionPool(database: database) {
                pool = existing
            } else {
                pool = try self.eventLoop.makeConnectionPool(
                    database: database,
                    using: self.make(Databases.self, for: Self.self)
                )
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

    /// Requests a connection to the database.
    /// important: you must be sure to call `.releaseConnection`
    public func requestConnection<Database>(
        to database: DatabaseIdentifier<Database>
    ) -> Future<Database.Connection> {
        return then {
            let pool: DatabaseConnectionPool<Database>

            /// this is the first attempt to connect to this
            /// db for this request
            if let existing = self.eventLoop.getConnectionPool(database: database) {
                pool = existing
            } else {
                pool = try self.eventLoop.makeConnectionPool(
                    database: database,
                    using: self.make(Databases.self, for: Self.self)
                )
            }

            /// request a connection from the pool
            return pool.requestConnection()
        }
    }

    /// Releases a connection back to the pool.
    /// important: make sure to return connections called by `requestConnection`
    /// to this function.
    public func releaseConnection<Database>(
        _ conn: Database.Connection,
        to database: DatabaseIdentifier<Database>
    ) throws {
        /// this is the first attempt to connect to this
        /// db for this request
        try requireConnectionPool(to: database).releaseConnection(conn)
    }

    /// Require a connection, throwing an error if none is found.
    internal func requireConnectionPool<Database>(
        to database: DatabaseIdentifier<Database>
    ) throws -> DatabaseConnectionPool<Database> {
        guard let pool = self.eventLoop.getConnectionPool(database: database) else {
            throw FluentError(
                identifier: "noReleasePool",
                reason: "No connection pool was found while attempting to release a connection."
            )
        }

        return pool
    }
}

/// Automatic connection releasing when the ephemeral worker deinits.
extension EphemeralContainer {
    /// See DatabaseConnectable.connect
    public func connect<D>(to database: DatabaseIdentifier<D>) -> Future<D.Connection> {
        if let current = connections[database.uid]?.connection as? Future<D.Connection> {
            return current
        }

        /// create an active connection, since we don't have to worry about threading
        /// we can be sure that .connection will be set before this is called again
        let active = ActiveConnection()
        connections[database.uid] = active

        let conn = requestConnection(to: database).map { conn -> D.Connection in
            /// first get a pointer to the pool
            let pool = try self.requireConnectionPool(to: database)

            /// then create an active connection that knows how to
            /// release itself
            active.release = {
                pool.releaseConnection(conn)
            }
            return conn
        }

        /// set the active connection so it is returned next time
        active.connection = active

        return conn
    }

    /// Releases all active connections.
    public func releaseConnections() {
        let conns = connections
        connections = [:]
        for (_, conn) in conns {
            conn.release!()
        }
    }

    /// This worker's active connections.
    fileprivate var connections: [String: ActiveConnection] {
        get { return extend["fluent:connections"] as? [String: ActiveConnection] ?? [:] }
        set { return extend["fluent:connections"] = newValue }
    }
}

/// Represents an active connection.
fileprivate final class ActiveConnection {
    typealias OnRelease = () -> ()
    var connection: Any?
    var release: OnRelease?

    init() {}
}
