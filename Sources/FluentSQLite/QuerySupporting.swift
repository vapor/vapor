import Async
import Fluent
import FluentSQL
import SQLite
import SQL

extension SQLiteConnection: QuerySupporting, JoinSupporting {
    /// See QueryExecutor.execute
    public func execute<I: InputStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) where I.Input == D {
        do {
            /// convert fluent query to sql query
            var (dataQuery, binds) = query.makeDataQuery()

            // create row encoder, will only
            // be used if a model is being binded
            let rowEncoder = SQLiteRowEncoder()

            // bind model columns to sql query
            if let model = query.data {
                try model.encode(to: rowEncoder)
                dataQuery.columns += rowEncoder.row.fields.keys.map {
                    DataColumn(table: query.entity, name: $0.name)
                }
            }

            /// create sqlite query from string
            let sqlString = SQLiteSQLSerializer().serialize(data: dataQuery)
            let sqliteQuery = self.query(string: sqlString)

            /// bind model data to sqlite query
            if query.data != nil {
                for data in rowEncoder.row.fields.values.map({ $0.data }) {
                    sqliteQuery.bind(data)
                }
            }

            /// encode sql placeholder binds
            let DataEncoder = SQLiteDataEncoder()
            for bind in binds {
                try sqliteQuery.bind(DataEncoder.makeSQLiteData(bind))
            }

            /// setup drain
            sqliteQuery.execute().do { results in
                if let results = results {
                    /// there are results to be streamed
                    results.stream().map(to: D.self) { row in
                        let decoder = SQLiteRowDecoder(row: row)
                        let model = try D(from: decoder)
                        return model
                    }.output(to: stream)
                } else {
                    stream.close()
                }
            }.catch { error in
                stream.error(error)
                stream.close()
            }
        } catch {
            stream.error(error)
            stream.close()
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
                throw FluentSQLiteError(identifier: "incorrect-string", reason: "could not convert value with wildcards to string: \(data)")
            }

            switch wildcard {
            case .fullWildcard: return .text("%" + string + "%")
            case .leadingWildcard: return .text("%" + string)
            case .trailingWildcard: return .text(string + "%")
            }
        }
    }
}

