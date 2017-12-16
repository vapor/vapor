import Async
import Service

/// Helper struct for configuring Fluent migrations.
public struct MigrationConfig {
    /// Internal storage.
    internal var storage: [String: MigrationRunnable]

    /// Create a new migration config helper.
    public init() {
        self.storage = [:]
    }

    /// Adds a migration to the config.
    public mutating func add<Migration, Database> (
        migration: Migration.Type,
        database: DatabaseIdentifier<Database>
    ) where
        Migration: Fluent.Migration,
        Migration.Database == Database
    {
        var config: QueryMigrationConfig<Database>

        if let existing = storage[database.uid] as? QueryMigrationConfig<Database> {
            config = existing
        } else {
            config = .init(database: database)
        }

        config.add(migration: Migration.self)
        storage[database.uid] = config
    }

    /// Adds a schema supporting migration to the config.
    public mutating func add<Migration, Database> (
        migration: Migration.Type,
        database: DatabaseIdentifier<Database>
    ) where
        Migration: Fluent.Migration,
        Migration.Database == Database,
        Database.Connection: SchemaSupporting
    {
        var config: SchemaMigrationConfig<Database>

        if let existing = storage[database.uid] as? SchemaMigrationConfig<Database> {
            config = existing
        } else {
            config = .init(database: database)
        }

        config.add(migration: Migration.self)
        storage[database.uid] = config
    }

    /// Adds a migration to the config.
    public mutating func add<Model, Database> (
        model: Model.Type,
        database: DatabaseIdentifier<Database>
    ) where
        Model: Fluent.Migration,
        Model: Fluent.Model,
        Model.Database == Database,
        Database.Connection: SchemaSupporting
    {
        self.add(migration: model, database: database)
        Model.defaultDatabase = database
    }

    /// Adds a migration to the config.
    public mutating func add<Model, Database> (
        model: Model.Type,
        database: DatabaseIdentifier<Database>
    ) where
        Model: Fluent.Migration,
        Model: Fluent.Model,
        Model.Database == Database
    {
        self.add(migration: model, database: database)
        Model.defaultDatabase = database
    }
}

/// Capable of running migrations when supplied databases and a worker.
/// We need this protocol because we lose some database type
/// info in our MigrationConfig storage.
internal protocol MigrationRunnable {
    func migrate(using databases: Databases, using container: Container) -> Future<Void>
}
