import Async
import Foundation

/// Represents a migration that has succesfully ran.
final class MigrationLog: Model, Timestampable {
    /// See Model.entity
    static let entity = "fluent"

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
    /// See Migration.prepare
    static func prepare(_ database: DatabaseConnection) -> Future<Void> {
        return database.create(self) { builder in
            builder.id()
            builder.string("name")
            builder.int("batch")
            builder.timestamps()
        }
    }

    /// See Migration.revert
    static func revert(_ database: DatabaseConnection) -> Future<Void> {
        return database.delete(self)
    }
}
