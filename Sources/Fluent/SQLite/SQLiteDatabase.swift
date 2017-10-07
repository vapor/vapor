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
    public func execute<M, I: InputStream, D: Decodable>(
        query: Query<M>,
        into stream: I
    ) -> Future<Void> where I.Input == D {
        let promise = Promise(Void.self)

        do {
            try _perform(query, into: stream)
                .then { promise.complete(()) }
                .catch { err in promise.fail(err) }
        } catch {
            promise.fail(error)
        }

        return promise.future
    }

    private func _perform<M, I: InputStream, D: Decodable>(
        _ fluentQuery: Query<M>,
        into stream: I
    ) throws -> Future<Void> where I.Input == D {
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

                    let encoder = SQLiteDataEncoder()
                    try value.encode(to: encoder)
                    values.append(encoder.data)
                default:
                    fatalError("not implemented")
                }

                select.predicates.append(predicate)
            }
            
            sqlQuery = .data(select)
        case .aggregate(let field, let aggregate):
            var select = DataQuery(statement: .select, table: M.entity)

            let count = DataComputed(function: "count", key: "fluentAggregate")
            select.computed.append(count)

            sqlQuery = .data(select)
        default:
            fatalError("\(fluentQuery.action) not yet supported")
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
                let model = try D(from: decoder)
                stream.inputStream(model)
            } catch {
                fatalError("uncaught error")
                // fluentQuery.errorStream?(error)
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
