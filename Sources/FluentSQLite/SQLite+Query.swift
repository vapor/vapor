import Async
import Fluent
import FluentSQL
import SQLite

extension SQLiteConnection: QueryExecutor {
    /// See QueryExecutor.execute
    public func execute<I: Async.InputStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) -> Future<Void> where I.Input == D {
        return then {
            /// create sqlite query
            let (dataQuery, encodables) = query.makeDataQuery()
            let sqlString = SQLiteSQLSerializer()
                .serialize(query: .data(dataQuery))
            let sqliteQuery = self.makeQuery(sqlString)

            /// encode data
            let encoder = SQLiteDataEncoder()
            for value in encodables {
                try value.encode(to: encoder)
                sqliteQuery.bind(encoder.data)
            }

            /// setup drain
            let promise = Promise(Void.self)
            sqliteQuery.drain { row in
                let decoder = SQLiteRowDecoder(row: row)
                do {
                    let model = try D(from: decoder)
                    stream.inputStream(model)
                } catch {
                    /// FIXME: should we fail or just put in the error stream?
                    promise.fail(error)
                }
            }.catch { err in
                /// FIXME: should we fail or just put in the error stream?
                promise.fail(err)
            }

            /// execute query
            sqliteQuery.execute().do {
                promise.complete()
            }.catch { err in
                promise.fail(err)
            }

            return promise.future
        }
    }
}




