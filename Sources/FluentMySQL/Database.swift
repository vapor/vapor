import Async
import MySQL
import Fluent

public struct MySQLDatabase {
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
}

extension MySQLDatabase : Database {
    public func makeConnection(on worker: Worker) -> Future<MySQLConnection> {
        return MySQLConnection.makeConnection(
            hostname: hostname,
            port: port,
            user: user,
            password:
            password,
            database: database,
            worker: worker
        )
    }
    
    public typealias Connection = MySQLConnection
}
