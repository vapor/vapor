import Service
import JunkDrawer
import Async
import Dispatch

/// An automatically managed pool of connections to a server.
///
/// [Learn More →](https://docs.vapor.codes/3.0/mysql/setup/#connecting)
public final class MySQLConnectionPool {
    /// The queue on which connections will be created
    let eventLoop: EventLoop
    
    /// The hostname to which connections will be connected
    let hostname: String
    
    /// The port to which connections will be connected
    let port: UInt16
    
    /// The username to authenticate with
    let user: String
    
    /// The password to authenticate with
    let password: String?
    
    /// The database to select
    let database: String
    
    /// A list of all currently active connections
    var pool = [ConnectionPair]()
    
    var waitQueue = [Promise<ConnectionPair>]()
    
    /// The maximum amount of connections in this pool
    ///
    /// Lowering this number may not result in closing connections
    public var maxConnections = 10
    
    class ConnectionPair {
        let connection: MySQLConnection
        var reserved = false
        
        init(connection: MySQLConnection) {
            self.connection = connection
        }
    }
    
    /// Creates a connection pool for a specific queue
    ///
    /// All connections in this pool will use this queue
    ///
    /// This pool is not threadsafe. Use one pool per thread
    public init(
        hostname: String,
        port: UInt16 = 3306,
        user: String,
        password: String?,
        database: String,
        on eventLoop: EventLoop
    ) {
        self.eventLoop = eventLoop
        self.hostname = hostname
        self.port = port
        self.user = user
        self.password = password
        self.database = database
    }
    
    func release(_ pair: ConnectionPair) {
        pair.reserved = false
        
        if waitQueue.count > 0 {
            waitQueue.removeFirst().complete(pair)
        }
    }
    
    typealias Complete = (()->())
    
    /// Retains a connection (or creates a new one) to execute the handler with
    ///
    /// Retained connections can only be used for a single query at a time
    ///
    ///
    public func retain<T>(_ handler: @escaping ((MySQLConnection) -> Future<T>)) -> Future<T> {
        let promise = Promise<ConnectionPair>()
        
        let future = promise.future.flatMap { pair -> Future<T> in
            pair.reserved = true
            
            // Runs the handler with the connection
            let future = handler(pair.connection)
                
            future.do { _ in
                self.release(pair)
            }.catch { _ in
                self.release(pair)
            }
            
            return future
        }
        
        // Checks for an existing connection
        pairChecker: for pair in pool where !pair.reserved {
            promise.complete(pair)
            
            return future
        }
        
        if self.pool.count >= maxConnections {
            let connectionPromise = Promise<ConnectionPair>()
            
            waitQueue.append(connectionPromise)
            
            connectionPromise.future.do(promise.complete).catch(promise.fail)
            
            return future
        }
        
        MySQLConnection.makeConnection(
            hostname: hostname,
            user: user,
            password: password,
            database: database,
            on: eventLoop
        ).do { connection in
            let pair = ConnectionPair(connection: connection)
            pair.reserved = true
            
            self.pool.append(pair)
            
            promise.complete(pair)
        }.catch(promise.fail)
        
        return future
    }
}
