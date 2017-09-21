import Core
import Dispatch

/// Used to cache and re-use connections.
public final class ConnectionPool {
    /// The database to use to generate new connections.
    public let database: Database

    /// The maximum number of connections this pool should hold.
    public let max: UInt

    /// The current number of active connections.
    private var active: UInt

    /// Maintain internal synchronization when accessing connections.
    private let lock: DispatchQueue

    /// Available connections.
    private var available: [Connection]

    /// Notified when more connections are available.
    private var waiters: [(Connection) -> ()]

    /// Create a new Connection Pool.
    public init(max: UInt, database: Database) {
        self.max = max
        self.available = []
        self.lock = DispatchQueue(label: "codes.vapor.sqlite.connectionpool.lock")
        self.active = 0
        self.database = database
        self.waiters = []
    }

    /// Ask the pool for a connection.
    public func makeConnection(on queue: DispatchQueue) throws -> Future<Connection> {
        let promise = Promise(Connection.self)


        lock.async {
            do {
                if let ready = self.available.popLast() {
                    promise.complete(ready)
                } else {
                    if self.active < self.max {
                        let connection = try self.database.makeConnection(on: queue)
                        self.active += 1
                        promise.complete(connection)
                    } else {
                        self.waiters.append(promise.complete)
                    }
                }
            } catch {
                promise.fail(error)
            }
        }

        return promise.future
    }

    /// Release a connection back to the pool
    public func releaseConnection(_ connection: Connection) {
        lock.async {
            if let waiter = self.waiters.popLast() {
                waiter(connection)
            } else {
                self.available.append(connection)
            }
        }
    }
}
