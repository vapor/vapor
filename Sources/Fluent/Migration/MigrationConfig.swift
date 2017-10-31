import Async

/// Helper struct for configuring Fluent migrations.
public struct MigrationConfig {
    /// Internal storage.
    internal var storage: [String: MigrationRunnable]

    /// Create a new migration config helper.
    public init() {
        self.storage = [:]
    }

    /// Adds a migration to the config.
    public mutating func add<M: Migration, D> (
        migration: M.Type,
        database: DatabaseIdentifier<D>
    ) where M.Database == D {
        var config: DatabaseMigrationConfig<D>

        if let existing = storage[database.uid] as? DatabaseMigrationConfig<D> {
            config = existing
        } else {
            config = .init(database: database)
        }

        config.add(migration: M.self)
        storage[database.uid] = config
    }
}

/// Capable of running a migration.
/// We need this protocol because we lose some database type
/// info in our MigrationConfig storage.
internal protocol MigrationRunnable {
    func migrate(using databases: Databases, on worker: Worker) -> Future<Void>
}
