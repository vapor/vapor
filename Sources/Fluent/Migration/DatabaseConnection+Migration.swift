import Async

extension DatabaseConnection {
    func prepare(_ migration: Migration.Type) -> Future<Void> {
        let promise = Promise(Void.self)

        hasPrepared(migration).then { hasPrepared in
            if hasPrepared {
                promise.complete()
            } else {
                migration.prepare(self).chain(to: promise)
            }
        }.catch(promise.fail)

        return promise.future
    }

    func revert(_ migration: Migration.Type) -> Future<Void> {
        let promise = Promise(Void.self)

        hasPrepared(migration).then { hasPrepared in
            if hasPrepared {
                migration.revert(self).chain(to: promise)
            } else {
                promise.complete()
            }
        }.catch(promise.fail)

        return promise.future
    }

    func hasPrepared(_ migration: Migration.Type) -> Future<Bool> {
        return query(MigrationLog.self)
            .filter("name" == migration.name)
            .first()
            .map { $0 != nil }
    }
}

extension Migration {
    fileprivate static var name: String {
        let _type = "\(type(of: self))"
        return _type.components(separatedBy: ".Type").first ?? _type
    }
}
