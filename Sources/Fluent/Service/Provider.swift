import Dispatch
import HTTP
import Service
import SQLite

public final class FluentProvider: Provider {
    public static var repositoryName: String = "fluent"

    public init() { }

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

    public func boot(_ container: Container) throws {
        let config = try container.make(MigrationConfig.self, for: FluentProvider.self)
        let databases = try container.make(Databases.self, for: FluentProvider.self)

        let migrationQueue = DispatchQueue(label: "codes.vapor.fluent.migration")

        for migration in config.migrations {
            guard let database = databases.storage[migration.database] else {
                throw "no database \(migration.database) was found for migration \(migration.migration)"
            }

            let conn = try database.makeConnection(on: migrationQueue).blockingAwait()
            print("Migrating \(migration.migration)")
            try migration.migration.prepare(conn).blockingAwait() // FIXME: is this fine being blocking?
            print("done!")
        }
    }
}

import Async

public protocol Migration {
    static func prepare(_ database: DatabaseConnection) -> Future<Void>
    static func revert(_ database: DatabaseConnection) -> Future<Void>
}

public struct Databases {
    public let storage: [DatabaseIdentifier: Database]
}

public struct DatabaseConfig {
    typealias LazyDatabase = (Container) throws -> Database

    var databases: [DatabaseIdentifier: LazyDatabase]

    public init() {
        self.databases = [:]
    }

    public mutating func add(
        database: Database,
        as id: DatabaseIdentifier = .default
    ) {
        databases[id] = { _ in database }
    }

    public mutating func add<D: Database>(
        database: D.Type,
        as id: DatabaseIdentifier = .default
    ) {
        databases[id] = { try $0.make(D.self, for: DatabaseConfig.self) }
    }
}

extension Model {
    public mutating func save(
        to req: Request,
        database: DatabaseIdentifier = .default,
        new: Bool = false
    ) throws -> Future<Void> {
        let query = try req.query(Self.self, database: database)
        return query.save(&self, new: new)
    }
}

public struct MigrationConfig {
    var migrations: [(migration: Migration.Type, database: DatabaseIdentifier)]

    public init() {
        self.migrations = []
    }

    public mutating func add<M: Migration>(
        migration: M.Type,
        database: DatabaseIdentifier = .default
    ) {
        migrations.append((M.self, database))
    }
}
