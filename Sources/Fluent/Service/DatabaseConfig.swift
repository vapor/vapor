import Async
import Service

/// Helper struct for configuring Fluent databases.
public struct DatabaseConfig {
    /// Lazy closure for initializing a database.
    public typealias LazyDatabase<D: Database> = (Container) throws -> D

    /// Internal storage.
    internal var databases: [String: (Container) throws -> Any]
    internal var logging: [String: DatabaseLogger]

    /// Create a new database config helper.
    public init() {
        self.databases = [:]
        self.logging = [:]
    }

    /// Add a pre-initialized database to the config.
    public mutating func add<D>(
        database: D,
        as id: DatabaseIdentifier<D>
    ) {
        databases[id.uid] = { _ in database }
    }

    /// Add a database type to the config. The application
    /// container will be asked to create this database type
    /// when it is used.
    public mutating func add<D>(
        database: D.Type,
        as id: DatabaseIdentifier<D>
    ) {
        databases[id.uid] = { try $0.make(D.self, for: DatabaseConfig.self) }
    }

    /// Adds a lazy-initialized database to the config.
    public mutating func add<D>(
        as id: DatabaseIdentifier<D>,
        database: @escaping LazyDatabase<D>
    ) {
        databases[id.uid] = database
    }

    /// Enables logging on the supplied database
    public mutating func enableLogging<D>(
        on database: DatabaseIdentifier<D>,
        logger: DatabaseLogger = .print
    ) where D: LogSupporting {
        logging[database.uid] = logger
    }
}
