import Async

/// Helper struct for configuring Fluent migrations.
public struct MigrationConfig {
    /// Internal storage.
    var migrations: [(migration: Migration.Type, database: DatabaseIdentifier)]

    /// Create a new migration config helper.
    public init() {
        self.migrations = []
    }

    /// Adds a migration to the config.
    public mutating func add<M: Migration>(
        migration: M.Type,
        database: DatabaseIdentifier = .default
    ) {
        migrations.append((M.self, database))
    }
}
