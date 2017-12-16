import Async
import Service

/// Internal struct containing migrations for a single database.
/// note: This struct is important for maintaining database connection type info.
internal struct SchemaMigrationConfig<
    Database: Fluent.Database
>: MigrationRunnable where Database.Connection: SchemaSupporting {
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

            return try database.makeConnection(from: container.make(for: Database.Connection.self), on: container).flatMap(to: Void.self) { conn in
                self.prepareForMigration(on: conn)
            }
        }
    }

    /// Prepares the connection for migrations by ensuring
    /// the migration log model is ready for use.
    internal func prepareForMigration(on conn: Database.Connection) -> Future<Void> {
        return MigrationLogMigration<Database>.prepareMetadata(on: conn).flatMap(to: Void.self) {
            return MigrationLog<Database>.latestBatch(on: conn).flatMap(to: Void.self) { lastBatch in
                return self.migrateBatch(on: conn, batch: lastBatch + 1)
            }
        }
    }

    /// Migrates this configs migrations under the current batch.
    /// Migrations that have already been prepared will be skipped.
    internal func migrateBatch(on conn: Database.Connection, batch: Int) -> Future<Void> {
        return migrations.map { migration in
            return { migration.prepareIfNeeded(batch: batch, on: conn) }
        }.syncFlatten()
    }

    /// Adds a migration to the config.
    internal mutating func add<M: Migration> (
        migration: M.Type
    ) where M.Database == Database {
        let container = MigrationContainer(migration)
        migrations.append(container)
    }
}


