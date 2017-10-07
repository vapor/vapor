import Async
import Dispatch
import SQL
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

    private func _perform<M>(_ fluentQuery: Query<M>) throws -> Future<Void> {
        let promise = Promise(Void.self)

        let sqlQuery: SQLQuery

        var values: [SQLiteData] = []

        switch fluentQuery.action {
        case .fetch:
            var select = DataQuery(statement: .select, table: M.entity)

            if let data = fluentQuery.data {
                let encoder = SQLiteRowEncoder()
                try data.encode(to: encoder)
                print(encoder.row)
                select.columns += encoder.row.fields.keys.map {
                    DataColumn(table: M.entity, name: $0.name)
                }
                // do this on insert
                // values += encoder.row.fields.values.map { $0.data }
            }

            for filter in fluentQuery.filters {
                let predicate: Predicate

                switch filter.method {
                case .compare(let field, let comp, let value):
                    predicate = Predicate(
                        table: filter.entity,
                        column: field,
                        comparison: .equal // FIXME: convert
                    )

                    let encoder = SQLiteRowEncoder()
                    try value.encode(to: encoder)
                    values.append(encoder.data)
                default:
                    fatalError("not implemented")
                }

                select.predicates.append(predicate)
            }
            
            sqlQuery = .data(select)
        default:
            fatalError("not implemented")
        }

        let string = SQLiteSQLSerializer()
            .serialize(query: sqlQuery)

        print(string)
        
        let sqliteQuery = try SQLiteQuery(
            statement: string,
            connection: self
        )

        for value in values {
            print(value)
            try sqliteQuery.bind(value)
        }

        sqliteQuery.drain { row in
            let decoder = SQLiteRowDecoder(row: row)
            do {
                let model = try M(from: decoder)
                fluentQuery.outputStream?(model)
            } catch {
                fluentQuery.errorStream?(error)
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
