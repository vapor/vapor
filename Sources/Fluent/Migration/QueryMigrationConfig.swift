import Async
import Service

/// Internal struct containing migrations for a single database.
/// note: This struct is important for maintaining database connection type info.
internal struct QueryMigrationConfig<Database: Fluent.Database>: MigrationRunnable {
    /// The database identifier for these migrations.
    internal let database: DatabaseIdentifier<Database>

    /// Internal storage.
    internal var migrations: [MigrationContainer<Database>]

    /// Create a new migration config helper.
    internal init(database: DatabaseIdentifier<Database>) {
        self.database = database
        self.migrations = []
    }

    /// See MigrationRunnable.migrate
    internal func migrate(using databases: Databases, using container: Container) -> Future<Void> {
        return Future {
            guard let database = databases.storage[self.database.uid] as? Database else {
                throw FluentError(identifier: "no-migration-database", reason: "no database \(self.database.uid) was found for migrations")
            }
            
            let config = try container.make(Database.Connection.Config.self, for: Database.Connection.self)

            return database.makeConnection(from: config, on: container).flatMap(to: Void.self) { conn in
                return self.migrateBatch(on: conn)
            }
        }
    }

    /// Migrates this configs migrations under the current batch.
    /// Migrations that have already been prepared will be skipped.
    internal func migrateBatch(on conn: Database.Connection) -> Future<Void> {
        return MigrationLog<Database>.latestBatch(on: conn).flatMap(to: Void.self) { lastBatch in
            return self.migrations.map { migration in
                return { migration.prepareIfNeeded(batch: lastBatch + 1, on: conn) }
            }.syncFlatten()
        }
    }

    /// Adds a migration to the config.
    internal mutating func add<M: Migration> (
        migration: M.Type
    ) where M.Database == Database {
        let container = MigrationContainer(migration)
        migrations.append(container)
    }
}

