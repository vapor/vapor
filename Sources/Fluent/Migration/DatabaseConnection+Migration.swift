import Async

extension DatabaseConnection {
    func blockingPrepare(_ migrations: [Migration.Type]) throws {
        // FIXME: make non-blocking even though it does't really matter
        try prepareMetadata().blockingAwait()
        let batch = try latestBatch().blockingAwait() + 1
        for migration in migrations {
            try prepare(migration, batch: batch).blockingAwait()
        }
    }

    // MARK: Private

    private func prepare(_ migration: Migration.Type, batch: Int = 0) -> Future<Void> {
        let promise = Promise(Void.self)

        hasPrepared(migration).then { hasPrepared in
            if hasPrepared {
                promise.complete()
            } else {
                migration.prepare(self).then {
                    // create the migration log
                    let log = MigrationLog(name: migration.name, batch: batch)
                    log.save(on: self).chain(to: promise)
                }.catch(promise.fail)
            }
        }.catch(promise.fail)

        return promise.future
    }

    private func revert(_ migration: Migration.Type) -> Future<Void> {
        let promise = Promise(Void.self)

        hasPrepared(migration).then { hasPrepared in
            if hasPrepared {
                migration.revert(self).then {
                    // delete the migration log
                    self.query(MigrationLog.self)
                        .filter("name" == migration.name)
                        .delete()
                        .chain(to: promise)
                }.catch(promise.fail)
            } else {
                promise.complete()
            }
        }.catch(promise.fail)

        return promise.future
    }

    private func hasPrepared(_ migration: Migration.Type) -> Future<Bool> {
        return query(MigrationLog.self)
            .filter("name" == migration.name)
            .first()
            .map { $0 != nil }
    }

    private func latestBatch() -> Future<Int> {
        return query(MigrationLog.self)
            .all()
            .map { logs in
                // FIXME: fluent sorting combined with first
                return logs.sorted { $0.batch > $1.batch }.first?.batch ?? 0
            }
    }

    private func prepareMetadata() -> Future<Void> {
        let promise = Promise(Void.self)

        query(MigrationLog.self).count().then { count in
            promise.complete()
        }.catch { err in
            // table needs to be created
            MigrationLog.prepare(self).chain(to: promise)
        }

        return promise.future
    }

    private func revertMetadata() -> Future<Void> {
        return MigrationLog.revert(self)
    }
}

extension Migration {
    fileprivate static var name: String {
        let _type = "\(type(of: self))"
        return _type.components(separatedBy: ".Type").first ?? _type
    }
}
