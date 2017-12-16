import Async

/// Contains a single migration.
/// note: we need this type for type erasing purposes.
internal struct MigrationContainer<D: Database> {
    /// static database type info
    /// note: this is important
    typealias Database = D

    /// the closure for performing the migration
    var prepare: (Database.Connection) -> Future<Void>

    /// the closure for reverting the migration
    var revert: (Database.Connection) -> Future<Void>

    /// this migration's unique name
    var name: String

    /// creates a new migration container for a given migration type
    init<M: Migration>(_ migration: M.Type) where M.Database == D {
        self.prepare = M.prepare
        self.revert = M.revert

        let _type = "\(type(of: M.self))"
        self.name = _type.components(separatedBy: ".Type").first ?? _type
    }

    /// prepares this migration only if it hasn't been previously.
    /// if prepared now, saves a migration log.
    internal func prepareIfNeeded(
        batch: Int,
        on connection: Database.Connection
    ) -> Future<Void> {
        return hasPrepared(on: connection).flatMap(to: Void.self) { hasPrepared in
            if hasPrepared {
                return .done
            } else {
                return self.prepare(connection).flatMap(to: Void.self) {
                    // create the migration log
                    let log = MigrationLog<Database>(name: self.name, batch: batch)
                    return QueryBuilder(MigrationLog<Database>.self, on: Future(connection))
                        .save(log)
                }
            }
        }
    }

    /// reverts this migration only if it hasn't previous run.
    /// if reverted, the migration log is deleted.
    internal func revertIfNeeded(on connection: Database.Connection) -> Future<Void> {
        return hasPrepared(on: connection).flatMap(to: Void.self) { hasPrepared in
            if hasPrepared {
                return self.revert(connection).flatMap(to: Void.self) {
                    // delete the migration log
                    return try QueryBuilder(MigrationLog<Database>.self, on: Future(connection))
                        .filter(\MigrationLog<Database>.name == self.name)
                        .delete()
                }
            } else {
                return .done
            }
        }
    }

    /// returns true if the migration has already been prepared.
    internal func hasPrepared(on connection: Database.Connection) -> Future<Bool> {
        return Future {
            return try QueryBuilder(MigrationLog<Database>.self, on: Future(connection))
                .filter(\MigrationLog<Database>.name == self.name)
                .first()
                .map(to: Bool.self) { $0 != nil }
        }
    }
}
