import Async
import Dispatch
import HTTP
import Service
import SQLite

/// Registers Fluent related services.
public final class FluentProvider: Provider {
    /// See Provider.repositoryName
    public static var repositoryName: String = "fluent"

    /// Creates a new Fluent provider.
    public init() { }

    /// See Provider.register()
    public func register(_ services: inout Services) throws {
        services.register { container -> SQLiteDatabase in
            let storage = try container.make(SQLiteStorage.self, for: SQLiteDatabase.self)
            return SQLiteDatabase(storage: storage)
        }

        services.register { container -> DatabaseMiddleware in
            let databases = try container.make(Databases.self, for: DatabaseMiddleware.self)
            return DatabaseMiddleware(databases: databases)
        }

        services.register { container -> Databases in
            let config = try container.make(DatabaseConfig.self, for: DatabaseMiddleware.self)
            var databases: [DatabaseIdentifier: Database] = [:]
            for (id, lazyDatabase) in config.databases {
                databases[id] = try lazyDatabase(container)
            }
            return Databases(storage: databases)
        }
    }

    /// See Provider.boot()
    public func boot(_ container: Container) throws {
        let config = try container.make(MigrationConfig.self, for: FluentProvider.self)
        let databases = try container.make(Databases.self, for: FluentProvider.self)

        let migrationQueue = DispatchQueue(label: "codes.vapor.fluent.migration")
        let migrationEventLoop = EventLoop(queue: migrationQueue)

        var organizedMigrations: [DatabaseIdentifier: [Migration.Type]] = [:]

        for migration in config.migrations {
            organizedMigrations[migration.database, default: []].append(migration.migration)
        }

        print(organizedMigrations)

        for (dbID, migrations) in organizedMigrations {
            guard let database = databases.storage[dbID] else {
                throw "no database \(dbID) was found for migrations \(migrations)"
            }

            let conn = try database.makeConnection(on: migrationEventLoop).blockingAwait()
            print("migrating \(dbID)")
            try conn.blockingPrepare(migrations)
        }

        print("done")
    }
}
