import Async
import Core
import SQL
import FluentSQL
import MySQL
import Fluent

/// A MySQL query serializer
internal final class MySQLSerializer: SQLSerializer {
    internal init () {}
}

/// An error that gets thrown if the ConnectionRepresentable needs to represent itself but fails to do so because it is used in a different context
struct InvalidConnectionType: Error{}

/// A Fluent wrapper around a MySQL connection that can log
public final class FluentMySQLConnection: Connection, JoinSupporting, ReferenceSupporting {
    /// Respresents the current FluentMySQLConnection as a connection to `D`
    public func makeConnection<D>(to database: DatabaseIdentifier<D>) -> Future<D.Connection> {
        guard let mysql = self as? D.Connection else {
            return Future(error: InvalidConnectionType())
        }
        
        return Future(mysql)
    }
    
    /// Keeps track of logs by MySQL
    let logger: MySQLLogger?
    
    /// The underlying MySQL Connection that can be used for normal queries
    public let connection: MySQLConnection
    
    /// Used to create a new FluentMySQLConnection wrapper
    init(connection: MySQLConnection, logger: MySQLLogger?) {
        self.connection = connection
        self.logger = logger
    }
    
    /// See QueryExecutor.execute
    public func execute<I, D: Decodable>(query: DatabaseQuery, into stream: I) where I : Async.InputStream, D == I.Input {
        /// convert fluent query to an abstract SQL query
        var (dataQuery, binds) = query.makeDataQuery()
        
        if let model = query.data {
            // Encode the model to read it's keys to be used inside the query
            let encoder = CodingPathKeyPreEncoder()
            
            do {
                dataQuery.columns += try encoder.keys(for: model).flatMap { keys in
                    guard let key = keys.first else {
                        return nil
                    }
                    
                    return DataColumn(name: key)
                }
            } catch {
                // Close the stream with an error
                stream.onError(error)
                stream.close()
                return
            }
        }
        
        /// Create a MySQL query string
        let sqlString = MySQLSerializer().serialize(data: dataQuery)
        
        _ = self.logger?.log(query: sqlString)
        
        // Prepares the statement for binding
        connection.withPreparation(statement: sqlString) { context -> Future<Void> in
            do {
                // Binds the model and other values
                let bound = try context.bind { binding in
                    try binding.withEncoder { encoder in
                        if let model = query.data {
                            try model.encode(to: encoder)
                        }
                        
                        for bind in binds {
                            try bind.encodable.encode(to: encoder)
                        }
                    }
                }
                
                // Streams all results into the parameter-provided stream
                let future = bound.forEach(D.self, stream.onInput)

                future.do {
                    // On success, close the stream
                    stream.close()
                }.catch { error in
                    // Close the stream with an error
                    stream.onError(error)
                    stream.close()
                }

                return future
            } catch {
                // Close the stream with an error
                stream.onError(error)
                stream.close()
                return Future(error: error)
            }
        }.catch { error in
            // Close the stream with an error
            stream.onError(error)
            stream.close()
        }
    }
    
    /// ReferenceSupporting.enableReferences
    public func enableReferences() -> Future<Void> {
        return connection.administrativeQuery("SET FOREIGN_KEY_CHECKS=1;")
    }

    /// ReferenceSupporting.disableReferences
    public func disableReferences() -> Future<Void> {
        return connection.administrativeQuery("SET FOREIGN_KEY_CHECKS=0;")
    }
    
    // FIXME: exposure from the MySQL driver
    public var lastAutoincrementID: Int? {
        if let id = connection.lastInsertID, id < numericCast(Int.max) {
            return numericCast(id)
        }
        
        return nil
    }
}

