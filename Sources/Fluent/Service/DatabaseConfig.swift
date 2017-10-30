import Service

/// Helper struct for configuring Fluent databases.
public struct DatabaseConfig {
    /// Lazy closure for initializing a database.
    public typealias LazyDatabase = (Container) throws -> Database

    /// Internal storage.
    var databases: [DatabaseIdentifier: LazyDatabase]

    /// Create a new database config helper.
    public init() {
        self.databases = [:]
    }

    /// Add a pre-initialized database to the config.
    public mutating func add(
        database: Database,
        as id: DatabaseIdentifier = .default
    ) {
        databases[id] = { _ in database }
    }

    /// Add a database type to the config. The application
    /// container will be asked to create this database type
    /// when it is used.
    public mutating func add<D: Database>(
        database: D.Type,
        as id: DatabaseIdentifier = .default
    ) {
        databases[id] = { try $0.make(D.self, for: DatabaseConfig.self) }
    }

    /// Adds a lazy-initialized database to the config.
    public mutating func add(
        as id: DatabaseIdentifier = .default,
        database: @escaping LazyDatabase
    ) {
        databases[id] = database
    }
}
