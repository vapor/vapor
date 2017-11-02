import Async
import Fluent
import FluentSQL
import SQLite
import SQL

extension SQLiteConnection: QueryExecutor {
    /// See QueryExecutor.execute
    public func execute<I: Async.InputStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) -> Future<Void> where I.Input == D {
        return then {
            // extract columns and data from
            // query data, if exists
            let modelColumns: [DataColumn]
            let modelData: [SQLiteData]

            if let model = query.data {
                let encoder = SQLiteRowEncoder()
                try model.encode(to: encoder)
                modelColumns = encoder.row.fields.keys.map {
                    DataColumn(table: query.entity, name: $0.name)
                }
                modelData = encoder.row.fields.values.map { $0.data }
            } else {
                modelColumns = []
                modelData = []
            }

            /// create sqlite query
            let (dataQuery, binds) = query.makeDataQuery(columns: modelColumns)
            let sqlString = SQLiteSQLSerializer()
                .serialize(data: dataQuery)
            let sqliteQuery = self.makeQuery(sqlString)

            /// bind model data
            for data in modelData {
                sqliteQuery.bind(data)
            }

            /// encode binds
            let encoder = SQLiteDataEncoder()
            for bind in binds {
                try sqliteQuery.bind(encoder.makeSQLiteData(bind))
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


extension SQLiteDataEncoder {
    /// Converts a SQL bind value into SQLite data.
    /// This method applies wildcards if necessary.
    fileprivate func makeSQLiteData(_ bind: BindValue) throws -> SQLiteData {
        try bind.encodable.encode(to: self)
        switch bind.method {
        case .plain:
            return data
        case .wildcard(let wildcard):
            // FIXME: fuzzy string
            guard let string = data.text else {
                throw "could not convert value with wildcards to string: \(data)"
            }

            switch wildcard {
            case .fullWildcard: return .text("%" + string + "%")
            case .leadingWildcard: return .text("%" + string)
            case .trailingWildcard: return .text(string + "%")
            }
        }
    }
}

