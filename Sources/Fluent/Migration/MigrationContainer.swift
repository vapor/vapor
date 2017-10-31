import Async

/// Contains type-erased migrations with database connection type info.
internal struct MigrationContainer<D: Database> where D.Connection: QueryExecutor {
    typealias Database = D

    var prepare: (Database.Connection) -> Future<Void>
    var revert: (Database.Connection) -> Future<Void>
    var name: String

    init<M: Migration>(_ migration: M.Type) where M.Database == D {
        self.prepare = M.prepare
        self.revert = M.revert

        let _type = "\(type(of: M.self))"
        self.name = _type.components(separatedBy: ".Type").first ?? _type
    }

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

    internal func hasPrepared(on connection: Database.Connection) -> Future<Bool> {
        return connection.query(MigrationLog<Database>.self)
            .filter("name" == name)
            .first()
            .map { $0 != nil }
    }
}
