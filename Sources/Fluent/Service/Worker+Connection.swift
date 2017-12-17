import Async
import JunkDrawer
import Service

// MARK: Connection

/// Create non-pooled connections that can be closed when done.
extension Container {
    /// Returns a future database connection for the
    /// supplied database identifier if one can be fetched.
    /// The database connection will be cached on this worker.
    /// The same database connection will always be returned for
    /// a given worker.
    public func withConnection<Database, T>(
        to database: DatabaseIdentifier<Database>,
        closure: @escaping (Database.Connection) throws -> Future<T>
    ) -> Future<T> {
        return makeConnection(to: database).flatMap(to: T.self) { conn in
            return try closure(conn).map(to: T.self) { e in
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
        return Future {
            let databases = try self.make(Databases.self, for: Self.self)

            guard let db = databases.storage[database.uid] as? Database else {
                throw FluentError(identifier: "database-not-configured", reason: "no database with id '\(database)' configured")
            }

            return try db.makeConnection(from: self.make(for: Database.Connection.self), on: self)
        }
    }
}

// MARK: Pool

extension Container {
    /// Returns a future database connection for the
    /// supplied database identifier if one can be fetched.
    /// The database connection will be cached on this worker.
    /// The same database connection will always be returned for
    /// a given worker.
    public func withPooledConnection<Database, T>(
        to database: DatabaseIdentifier<Database>,
        closure: @escaping (Database.Connection) throws -> Future<T>
    ) -> Future<T> {
        return Future {
            let cache = try self.make(ConnectionPoolCache.self, for: Database.self)
            let pool = try cache.pool(for: database)

            /// request a connection from the pool
            return pool.requestConnection().flatMap(to: T.self) { conn in
                return try closure(conn).map(to: T.self) { res in
                    pool.releaseConnection(conn)
                    return res
                }
            }
        }
    }

    /// Requests a connection to the database.
    /// important: you must be sure to call `.releaseConnection`
    public func requestPooledConnection<Database>(
        to database: DatabaseIdentifier<Database>
    ) -> Future<Database.Connection> {
        return Future {
            let cache = try self.make(ConnectionPoolCache.self, for: Database.self)
            let pool = try cache.pool(for: database)

            /// request a connection from the pool
            return pool.requestConnection()
        }
    }

    /// Releases a connection back to the pool.
    /// important: make sure to return connections called by `requestConnection`
    /// to this function.
    public func releasePooledConnection<Database>(
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
        let cache = try self.make(ConnectionPoolCache.self, for: Database.self)
        return try cache.pool(for: database)
    }
}

// MARK: Ephemeral

/// Automatic connection releasing when the ephemeral worker deinits.
extension EphemeralContainer {
    /// See DatabaseConnectable.connect
    public func connect<D>(to database: DatabaseIdentifier<D>) -> Future<D.Connection> {
        return Future {
            let connections = try self.make(ActiveConnectionCache.self, for: Self.self)
            if let current = connections.cache[database.uid]?.connection as? Future<D.Connection> {
                return current
            }

            /// create an active connection, since we don't have to worry about threading
            /// we can be sure that .connection will be set before this is called again
            let active = ActiveConnection()
            connections.cache[database.uid] = active

            let conn = self.superContainer.requestPooledConnection(to: database).map(to: D.Connection.self) { conn in
                /// first get a pointer to the pool
                let pool = try self.superContainer.requireConnectionPool(to: database)

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
    }

    /// Releases all active connections.
    public func releaseConnections() throws {
        let connections = try self.make(ActiveConnectionCache.self, for: Self.self)
        let conns = connections.cache
        connections.cache = [:]
        for (_, conn) in conns {
            conn.release!()
        }
    }
}


// MARK: Internal

/// Represents an active connection.
internal final class ActiveConnection {
    typealias OnRelease = () -> ()
    var connection: Any?
    var release: OnRelease?

    init() {}
}

internal final class ActiveConnectionCache {
    var cache: [String: ActiveConnection]
    init() {
        self.cache = [:]
    }
}

internal final class ConnectionPoolCache {
    let databases: Databases
    var cache: [String: Any]
    let container: Container

    init(databases: Databases, on container: Container) {
        self.databases = databases
        self.container = container
        self.cache = [:]
    }

    func pool<D>(for id: DatabaseIdentifier<D>) throws -> DatabaseConnectionPool<D>
    {
        if let existing = cache[id.uid] as? DatabaseConnectionPool<D> {
            return existing
        } else {
            guard let database = databases.storage[id.uid] as? D else {
                fatalError("no database")
            }

            let new = try database.makeConnectionPool(max: 2, using: container.make(for: D.Connection.self), on: container)
            cache[id.uid] = new
            return new
        }
    }
}

