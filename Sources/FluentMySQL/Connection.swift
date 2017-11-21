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
        /// convert fluent query to sql query
        let (dataQuery, binds) = query.makeDataQuery()
        
        /// create sqlite query from string
        let sqlString = MySQLSerializer().serialize(data: dataQuery)
        
        _ = self.withPreparation(statement: sqlString) { context -> Future<Void> in
            do {
                let bound = try context.bind { binding in
                    try binding.withEncoder { encoder in
                        if let model = query.data {
                            try model.encode(to: encoder)
                        } else {
                            for bind in binds {
                                try bind.encodable.encode(to: encoder)
                            }
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
    }
    
    public var lastAutoincrementID: Int? {
        return nil
    }
}

