import Core
import Async
import Dispatch

/// An automatically managed pool of connections to a server.
///
/// http://localhost:8000/mysql/setup/#connecting
public class ConnectionPool {
    /// The queue on which connections will be created
    let worker: Worker
    
    /// The hostname to which connections will be connected
    let hostname: String
    
    /// The port to which connections will be connected
    let port: UInt16
    
    /// The username to authenticate with
    let user: String
    
    /// The password to authenticate with
    let password: String?
    
    /// The database to select
    let database: String?
    
    /// A list of all currently active connections
    var pool = [ConnectionPair]()
    
    class ConnectionPair {
        let connection: Connection
        var reserved = false
        
        init(connection: Connection) {
            self.connection = connection
        }
    }
    
    /// Creates a connection pool for a specific queue
    ///
    /// All connections in this pool will use this queue
    ///
    /// This pool is not threadsafe. Use one pool per thread
    public init(hostname: String, port: UInt16 = 3306, user: String, password: String?, database: String?, worker: Worker) {
        self.worker = worker
        self.hostname = hostname
        self.port = port
        self.user = user
        self.password = password
        self.database = database
    }
    
    typealias Complete = (()->())
    
    /// Retains a connection (or creates a new one) to execute the handler with
    internal func retain<T>(_ handler: @escaping ((Connection, @escaping ((T) -> ()), @escaping Stream.ErrorHandler) -> Void)) -> Future<T> {
        let promise = Promise<T>()
        
        // Checks for an existing connection
        for pair in pool where !pair.reserved {
            pair.reserved = true
            
            // Runs the handler with the connection
            handler(pair.connection, { result in
                // On completion, return the connection, complete the promise
                pair.reserved = false
                promise.complete(result)
            }) { error in
                pair.reserved = false
                promise.fail(error)
            }
            
            return promise.future
        }

        Connection.makeConnection(hostname: hostname, user: user, password: password, database: database, worker: worker).do { connection in
            let pair = ConnectionPair(connection: connection)
            pair.reserved = true
            
            self.pool.append(pair)
            
            // Runs the handler with the connection
            handler(pair.connection, { result in
                // On completion, return the connection, complete the promise
                pair.reserved = false
                promise.complete(result)
            }) { error in
                pair.reserved = false
                promise.fail(error)
            }
        }.catch(promise.fail)
        
        return promise.future
    }
}
