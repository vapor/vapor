import Foundation
import Core

/// Responsible for maintaing a pool
/// of connections, one for each thread.
public final class ThreadConnectionPool {

    /// Thread Pool Errors
    public enum Error: Swift.Error {
        //// Something in our internal lock mechanism has unexpectedly failed
        /// ... should never see this except for more widespread system
        /// dispatch errors
        case lockFailure

        /// The maximum number of active connections has been reached and the pool
        /// is no longer capable of creating new ones.
        case maxConnectionsReached(max: Int)

        /// This is here to allow extensibility w/o breaking apis, it is not currently
        /// used, but should be accounted for by end user if they are handling the
        /// error
        case unspecified(Swift.Error)
    }

    private static var threadId: pthread_t {
        // must run every time, do not assign
        return pthread_self()
    }

    /// The maximum amount of connections permitted in the pool
    public var maxConnections: Int

    /// When the maximum amount of connections has been reached and all connections
    /// are in use at time of request, how long should the system wait
    /// until it gives up and throws an error.
    ///
    /// default is 10 seconds.
    public var connectionPendingTimeoutSeconds: Int = 10

    private var connections: [String: Connection]
    private let connectionsLock: NSLock
    private let driver: Driver

    /// Initializes a thread pool with a connectionFactory intended to construct
    /// new connections when appropriate and an Integer defining the maximum
    /// number of connections the pool is allowed to make
    public init(_ driver: Driver, maxConnections: Int) {
        self.driver = driver
        self.maxConnections = maxConnections
        connections = [:]
        connectionsLock = NSLock()
    }
    
    internal func connection(_ type: ConnectionType) throws -> Connection {
        let typeString: String
        switch type {
        case .readWrite:
            typeString = "rw"
        case .read:
            typeString = "r"
        }
        let id = "\(typeString)_\(ThreadConnectionPool.threadId.hashValue)"
        
        //  Because we might wait inside of the makeNewConnection function,
        //  do NOT attempt to wrap this within connectionLock or it may
        //  be blocked from other threads
        //
        //  In the makeConnection call, there will be a threadsafe check to prevent
        //  creating duplicates.
        //
        //  It shouldn't happen that two calls come on same thread anyways, but
        //  in the interest of 'just in case'
        guard let existing = connections[id], !existing.isClosed else {
            let connection: Connection

            // FIXME: no locking!
            connectionsLock.lock()
            //  Just in case our first attempt to access failed in a non thread safe manner
            //  to prevent duplicates, we do a quick check here.
            //
            //  Likely redundant, but beneficial for safety.
            //
            if let existing = connections[id], !existing.isClosed {
                connection = existing
            } else {
                connections[id] = nil

                // Attempt to make space if possible
                if connections.keys.count >= maxConnections { clearClosedConnections() }
                // If space hasn't been created, attempt to wait for space
                if connections.keys.count >= maxConnections { waitForSpace() }
                // the maximum number of connections has been created, even after attempting to clear out closed connections
                if connections.keys.count >= maxConnections { throw Error.maxConnectionsReached(max: maxConnections) }
                let c = try driver.makeConnection(type)
                connections[id] = c
                connection = c
            }
            connectionsLock.unlock()

            return connection
        }
        
        return existing
    }

    private func waitForSpace() {
        var waited = 0
        while waited < connectionPendingTimeoutSeconds, connections.keys.count >= maxConnections {
            sleep(1)
            clearClosedConnections()
            waited += 1
        }
    }

    private func clearClosedConnections() {
        connections.forEach { thread, connection in
            guard connection.isClosed else { return }
            connections[thread] = nil
        }
    }
}

extension ThreadConnectionPool: Executor {
    public var queryLogger: QueryLogger? {
        // connection is responsible for
        // query logging
        get { return nil }
        set { }
    }
    
    public func query<E, D: Decodable>(_ query: RawOr<Query<E>>) throws -> D {
        let type: ConnectionType
        switch query {
        case .raw:
            type = .readWrite
        case .some(let q):
            type = q.connectionType
        }
        
        do {
            return try connection(type)
                .query(query)
        } catch QueryError.connectionClosed {
            // try again for closed connections
            return try connection(type)
                .query(query)
        }
    }
}
