import Async
import Foundation

/// Represents a migration that has succesfully ran.
final class MigrationLog: Model, Timestampable {
    /// See Model.ID
    typealias ID = UUID

    /// See Model.entity
    static let entity = "fluent"

    /// See Model.idKeyPath
    static let idKey = \MigrationLog.id

    /// See Model.keyPathMap
    static let keyFieldMap = [
        key(\.id): field("id"),
        key(\.name): field("name"),
        key(\.batch): field("batch"),
        key(\.createdAt): field("createdAt"),
        key(\.updatedAt): field("updatedAt"),
    ]

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

    /// Create a new migration log
    init(id: UUID? = nil, name: String, batch: Int) {
        self.id = id
        self.name = name
        self.batch = batch
    }
}

/// MARK: Migration
final class MigrationLogMigration<
    D: Fluent.Database
>: Migration where D.Connection: SchemaSupporting {
    public typealias Database = D

    /// See Migration.prepare
    static func prepare(on connection: Database.Connection) -> Future<Void> {
            return connection.create(MigrationLog.self) { builder in
                try builder.field(for: \.id)
                try builder.field(for: \.name)
                try builder.field(for: \.batch)
                try builder.field(for: \.createdAt)
                try builder.field(for: \.updatedAt)
            }
    }

    /// See Migration.revert
    static func revert(on connection: Database.Connection) -> Future<Void> {
        return connection.delete(MigrationLog.self)
    }

}

/// MARK: Internal

extension MigrationLog {
    /// Returns the latest batch number.
    /// note: returns 0 if no batches have run yet.
    internal static func latestBatch<Connection: Fluent.Connection>(
        on connection: Connection
    ) -> Future<Int> {
        return then {
            return try connection.query(MigrationLog.self)
                .sort("batch", .descending)
                .first()
                .map { log in
                    return log?.batch ?? 0
            }
        }
    }
}

extension MigrationLogMigration {
    /// Prepares the connection for storing migration logs.
    /// note: this is unlike other migrations since we are checking
    /// for an error instead of asking if the migration has already prepared.
    internal static func prepareMetadata(on connection: Database.Connection) -> Future<Void> {
        let promise = Promise(Void.self)

        connection.query(MigrationLog.self).count().do { count in
            promise.complete()
        }.catch { err in
            // table needs to be created
            prepare(on: connection).chain(to: promise)
        }

        return promise.future
    }

    /// For parity, reverts the migration metadata.
    /// This simply calls the migration revert function.
    internal static func revertMetadata(on connection: Database.Connection) -> Future<Void> {
        return self.revert(on: connection)
    }
}
