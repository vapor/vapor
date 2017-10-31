import Async
import Foundation

/// Represents a migration that has succesfully ran.
final class MigrationLog<D: Database>: Model, Timestampable where D.Connection: QueryExecutor {
    /// See Model.entity
    static var entity: String { return "fluent" }

    /// See Model.id
    var id: UUID?

    /// The unique name of the migration.
    var name: String

    /// The batch number.
    var batch: Int

    /// See Timestampable.createdAt
    var createdAt: Date?

    /// See Timestampable.updatedAt
    var updatedAt: Date?

    init(id: UUID? = nil, name: String, batch: Int) {
        self.id = id
        self.name = name
        self.batch = batch
    }
}

/// MARK: Migration
extension MigrationLog: Migration {
    typealias Database = D

    /// See Migration.prepare
    static func prepare(on connection: Database.Connection) -> Future<Void> {
        if let schema = connection as? SchemaExecutor {
            return schema.create(self) { builder in
                builder.id()
                builder.string("name")
                builder.int("batch")
                builder.timestamps()
            }
        } else {
            return Future(())
        }
    }

    /// See Migration.revert
    static func revert(on connection: Database.Connection) -> Future<Void> {
        if let schema = connection as? SchemaExecutor {
            return schema.delete(self)
        } else {
            return Future(())
        }
    }
}

/// MARK: Private

extension MigrationLog {
    internal static func latestBatch(on connection: Database.Connection) -> Future<Int> {
        return connection.query(MigrationLog<Database>.self)
            .all()
            .map { logs in
                // FIXME: fluent sorting combined with first
                return logs.sorted { $0.batch > $1.batch }.first?.batch ?? 0
            }
    }


    internal static func prepareMetadata(on connection: Database.Connection) -> Future<Void> {
        let promise = Promise(Void.self)

        connection.query(self).count().then { count in
            promise.complete()
        }.catch { err in
            // table needs to be created
            prepare(on: connection).chain(to: promise)
        }

        return promise.future
    }

    internal static func revertMetadata(on connection: Database.Connection) -> Future<Void> {
        return self.revert(on: connection)
    }
}
