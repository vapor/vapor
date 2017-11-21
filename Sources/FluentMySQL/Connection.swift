import Async
import SQL
import FluentSQL
import MySQL
import Fluent

public final class MySQLSerializer: SQLSerializer {
    public init () {}
}

extension MySQLConnection: Connection {
    public func execute<I, D>(query: DatabaseQuery, into stream: I) where I : ClosableStream, I : InputStream, D : Decodable, D == I.Input {
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
            let sqlString = MySQLSerializer().serialize(data: dataQuery)
            
            _ = self.withPreparation(statement: sqlString) { context -> Future<Void> in
                do {
                    let bound = try context.bind { binding in
                        if let model = query.data {
                            try binding.bind(model: model)
                        } else {
                            for bind in binds {
                                bind.method
                            }
                        }
                    }
                    
                    try bound.stream(D.self).drain(into: stream)
                    return Future<Void>(())
                } catch {
                    stream.errorStream?(error)
                    stream.close()
                    return Future(error: error)
                }
            }
            
            /// bind model data to sqlite query
            if query.data != nil {
                for data in rowEncoder.row.fields.values.map({ $0.data }) {
                    sqliteQuery.bind(data)
                }
            }
            
            /// encode sql placeholder binds
            let dataEncoder = SQLiteDataEncoder()
            for bind in binds {
                try sqliteQuery.bind(dataEncoder.makeSQLiteData(bind))
            }
            
            /// setup drain
            sqliteQuery.drain { row in
                let decoder = SQLiteRowDecoder(row: row)
                do {
                    let model = try D(from: decoder)
                    stream.input(model)
                } catch {
                    stream.errorStream?(error)
                    stream.close()
                }
            }.catch { err in
                stream.errorStream?(err)
                stream.close()
            }
            
            /// execute query
            sqliteQuery.execute().do {
                stream.close()
                }.catch { err in
                    stream.errorStream?(err)
                    stream.close()
            }
        } catch {
            stream.errorStream?(error)
            stream.close()
        }
    }
    
    public var lastAutoincrementID: Int? {
        return nil
    }
}

