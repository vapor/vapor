import Service

/// Registers and boots MySQL services.
public final class MySQLProvider: Provider {
    /// See Provider.repositoryName
    public static let repositoryName = "fluent-mysql"
    
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
    
    public init(hostname: String, port: UInt16 = 3306, user: String, password: String?, database: String) {
        self.hostname = hostname
        self.port = port
        self.user = user
        self.password = password
        self.database = database
    }
    
    /// See Provider.register
    public func register(_ services: inout Services) throws {
        services.instance(FluentMySQLConfig())
        services.register(MySQLDatabase.self) { container -> MySQLDatabase in
            return MySQLDatabase(
                hostname: self.hostname,
                port: self.port,
                user: self.user,
                password: self.password,
                database: self.database
            )
        }
    }
    
    /// See Provider.boot
    public func boot(_ container: Container) throws {}
}

