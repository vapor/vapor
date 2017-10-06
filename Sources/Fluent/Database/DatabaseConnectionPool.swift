import Async
import Dispatch

/// Pools database connections for re-use.
public final class DatabaseConnectionPool {
    /// The database to use to generate new connections.
    public let database: Database

    /// The queue for this pool
    public let queue: DispatchQueue

    /// The maximum number of connections this pool should hold.
    public let max: UInt

    /// The current number of active connections.
    private var active: UInt

    /// Available connections.
    private var available: [DatabaseConnection]

    /// Notified when more connections are available.
    private var waiters: [(DatabaseConnection) -> ()]

    /// Create a new Queue pool
    public init(max: UInt, database: Database, queue: DispatchQueue) {
        self.database = database
        self.queue = queue
        self.max = max
        self.active = 0
        self.available = []
        self.waiters = []
    }

    /// Request a connection from this queue pool.
    public func requestConnection() -> Future<DatabaseConnection> {
        let promise = Promise(DatabaseConnection.self)

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

        return promise.future
    }

    /// Release a connection back to the queue pool.
    public func releaseConnection(_ connection: DatabaseConnection) {
        if let waiter = self.waiters.popLast() {
            waiter(connection)
        } else {
            self.available.append(connection)
        }
    }
}

