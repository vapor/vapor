import Async
import Dispatch
import SQLite

extension SQLiteDatabase: Database {
    public func makeConnection(
        on queue: DispatchQueue
    ) throws -> DatabaseConnection {
        return try SQLiteConnection(database: self, queue: queue)
    }
}

extension SQLiteConnection: DatabaseConnection {
    public func execute<M>(_ query: Query<M>) -> Future<Void> {
        let promise = Promise(Void.self)

        do {
            try _perform(query)
                .then { promise.complete(()) }
                .catch { err in promise.fail(err) }
        } catch {
            promise.fail(error)
        }

        return promise.future
    }

    private func _perform<M>(_ query: Query<M>) throws -> Future<Void> {
        let promise = Promise(Void.self)

        let sqliteQuery = try SQLiteQuery(
            statement: query.sql!,
            connection: self
        )

        if let data = query.data {
            let encoder = SQLiteRowEncoder()
            try data.encode(to: encoder)
            print(encoder.row)
        }

        sqliteQuery.drain { row in
            let decoder = SQLiteRowDecoder(row: row)
            do {
                let model = try M(from: decoder)
                query.outputStream?(model)
            } catch {
                query.errorStream?(error)
            }
        }.catch { err in
            promise.fail(err)
        }

        sqliteQuery.execute().then {
            promise.complete()
        }.catch { err in
            promise.fail(err)
        }

        return promise.future
    }
}
