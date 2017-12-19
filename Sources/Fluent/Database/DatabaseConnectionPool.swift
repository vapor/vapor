import Async
import Service
import Dispatch

/// Pools database connections for re-use.
public final class DatabaseConnectionPool<Database: Fluent.Database> {
    /// The database to use to generate new connections.
    public let database: Database

    /// The Worker for this pool
    public let eventLoop: EventLoop
    
    /// The configuration to be used for connections in this pool
    public let config: Database.Connection.Config

    /// The maximum number of connections this pool should hold.
    public let max: UInt

    /// The current number of active connections.
    private var active: UInt

    /// Available connections.
    private var available: [Database.Connection]

    /// Notified when more connections are available.
    private var waiters: [(Database.Connection) -> ()]

    /// Create a new Queue pool
    public init(
        max: UInt,
        database: Database,
        using config: Database.Connection.Config,
        on worker: Worker
    ) {
        self.database = database
        self.eventLoop = worker.eventLoop
        self.config = config
        self.max = max
        self.active = 0
        self.available = []
        self.waiters = []
    }

    /// Request a connection from this queue pool.
    public func requestConnection() -> Future<Database.Connection> {
        let promise = Promise(Database.Connection.self)

        if let ready = self.available.popLast() {
            promise.complete(ready)
        } else if self.active < self.max {
            self.database.makeConnection(from: config, on: eventLoop).do { connection in
                self.active += 1
                if let references = connection as? _ReferenceSupporting {
                    references.enableReferences().do {
                        promise.complete(connection)
                    }.catch(promise.fail)
                } else {
                    promise.complete(connection)
                }
            }.catch { err in
                promise.fail(err)
            }
        } else {
            self.waiters.append(promise.complete)
        }

        return promise.future
    }

    /// Release a connection back to the queue pool.
    public func releaseConnection(_ connection: Database.Connection) {
        if let waiter = self.waiters.popLast() {
            waiter(connection)
        } else {
            self.available.append(connection)
        }
    }
}

