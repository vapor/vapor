import Core
import Dispatch

public class ConnectionPool {
    /// The queue on which connections will be created
    let queue: DispatchQueue
    
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
    public init(hostname: String, port: UInt16 = 3306, user: String, password: String?, database: String?, queue: DispatchQueue) {
        self.queue = queue
        self.hostname = hostname
        self.port = port
        self.user = user
        self.password = password
        self.database = database
    }
    
    typealias Complete = (()->())
    
    internal func retain(_ handler: @escaping ((Connection, @escaping Complete) -> ())) throws {
        for pair in pool where !pair.reserved {
            pair.reserved = true
            handler(pair.connection) {
                pair.reserved = false
            }
        }
        
        _ = try Connection.makeConnection(hostname: hostname, user: user, password: password, database: database, queue: queue).then { connection in
            let pair = ConnectionPair(connection: connection)
            pair.reserved = true
            
            self.pool.append(pair)
            
            handler(pair.connection) {
                pair.reserved = false
            }
        }
    }
    
    /// Loops over all rows resulting from the query
    ///
    /// - parameter type: Deserializes all rows to the provided `Decodable` `D`
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each deserialized result
    public func forEach<D: Decodable>(_ type: D.Type, in query: Query, _ handler: @escaping ((D) -> ())) throws {
        try retain { connection, complete in
            // Set up a parser
            let resultBuilder = ModelBuilder<D>(connection: connection)
            connection.receivePackets(into: resultBuilder.inputStream)
            
            resultBuilder.complete = {
                complete()
            }
            
            resultBuilder.errorStream = { error in
                complete()
            }
            
            resultBuilder.drain(handler)
            
            // Send the query
            do {
                try connection.write(query: query.string)
            } catch {
                complete()
            }
        }
    }
}
