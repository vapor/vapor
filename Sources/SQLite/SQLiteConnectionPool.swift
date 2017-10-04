import Async
import Dispatch

public final class SQLiteConnectionPool {
    /// The database to use to generate new connections.
    public let database: SQLiteDatabase

    /// The queue for this pool
    public let queue: DispatchQueue

    /// The maximum number of connections this pool should hold.
    public let max: UInt

    /// The current number of active connections.
    private var active: UInt

    /// Available connections.
    private var available: [SQLiteConnection]

    /// Notified when more connections are available.
    private var waiters: [(SQLiteConnection) -> ()]

    /// Create a new Queue pool
    public init(max: UInt, database: SQLiteDatabase, queue: DispatchQueue) {
        self.database = database
        self.queue = queue
        self.max = max
        self.active = 0
        self.available = []
        self.waiters = []
    }

    /// Request a connection from this queue pool.
    public func requestConnection() -> Future<SQLiteConnection> {
        let promise = Promise(SQLiteConnection.self)

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
    public func releaseConnection(_ connection: SQLiteConnection) {
        if let waiter = self.waiters.popLast() {
            waiter(connection)
        } else {
            self.available.append(connection)
        }
    }
}
