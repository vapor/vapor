import Async
import Service
import MySQL
import Fluent

/// A reference to a MySQL database
public final class MySQLDatabase : LogSupporting {
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
    
    /// If set, query logs will be sent to the supplied logger.
    public var logger: MySQLLogger?
    
    public init(hostname: String, port: UInt16 = 3306, user: String, password: String?, database: String) {
        self.hostname = hostname
        self.port = port
        self.user = user
        self.password = password
        self.database = database
    }
    
    /// See SupportsLogging.enableLogging
    public func enableLogging(using logger: DatabaseLogger) {
        self.logger = logger
    }
}

extension MySQLDatabase : Database {
    public func makeConnection(from config: FluentMySQLConfig, on worker: Worker) -> Future<FluentMySQLConnection> {
        return MySQLConnection.makeConnection(
            hostname: hostname,
            port: port,
            ssl: config.ssl,
            user: user,
            password: password,
            database: database,
            on: worker.eventLoop
        ).map(to: FluentMySQLConnection.self) { connection in
            return FluentMySQLConnection(connection: connection, logger: self.logger)
        }
    }
    
    public typealias Connection = FluentMySQLConnection
}
