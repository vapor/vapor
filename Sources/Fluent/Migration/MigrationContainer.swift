import Async

/// Contains a single migration.
/// note: we need this type for type erasing purposes.
internal struct MigrationContainer<D: Database> where D.Connection: QueryExecutor {
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
        let promise = Promise(Void.self)

        hasPrepared(on: connection).then { hasPrepared in
            if hasPrepared {
                promise.complete()
            } else {
                self.prepare(connection).then {
                    // create the migration log
                    let log = MigrationLog<Database>(name: self.name, batch: batch)
                    log.save(on: connection).chain(to: promise)
                }.catch(promise.fail)
            }
        }.catch(promise.fail)

        return promise.future
    }

    /// reverts this migration only if it hasn't previous run.
    /// if reverted, the migration log is deleted.
    internal func revertIfNeeded(on connection: Database.Connection) -> Future<Void> {
        let promise = Promise(Void.self)

        hasPrepared(on: connection).then { hasPrepared in
            if hasPrepared {
                self.revert(connection).then {
                    // delete the migration log
                    connection.query(MigrationLog<Database>.self)
                        .filter("name" == self.name)
                        .delete()
                        .chain(to: promise)
                    }.catch(promise.fail)
            } else {
                promise.complete()
            }
        }.catch(promise.fail)

        return promise.future
    }

    /// returns true if the migration has already been prepared.
    internal func hasPrepared(on connection: Database.Connection) -> Future<Bool> {
        return connection.query(MigrationLog<Database>.self)
            .filter("name" == name)
            .first()
            .map { $0 != nil }
    }
}
