import TLS
import MySQL

/// A Fluent + MySQL configuration file
public struct FluentMySQLConfig {
    /// If set, the MySQL connection will use these SSL settings
    public var ssl: MySQLSSLConfig?
    
    /// Creates a new basic MySQL configuration
    public init() {}
}
