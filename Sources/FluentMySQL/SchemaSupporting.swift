import Foundation
import Async
import SQL
import Fluent
import FluentSQL
import MySQL

extension FluentMySQLConnection : SchemaSupporting, TransactionSupporting {
    /// Runs a transaction on the MySQL connection
    public func execute(transaction: DatabaseTransaction<FluentMySQLConnection>) -> Future<Void> {
        let promise = Promise<Void>()
        
        connection.administrativeQuery("START TRANSACTION").flatMap(to: Void.self) {
            return transaction.run(on: self)
        }.addAwaiter { result in
            if let error = result.error {
                self.connection.administrativeQuery("ROLLBACK").do {
                    // still fail even though rollback succeeded
                    promise.fail(error)
                }.catch { error in
                    promise.fail(error)
                }
            } else {
                promise.complete()
            }
        }
        
        return promise.future
    }
    
    public typealias FieldType = ColumnType
    
    /// Executes the schema query
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        let query = schema.makeSchemaQuery()
        _ = self.logger?.log(query: query)
        
        return connection.administrativeQuery(query)
    }
}

extension ColumnType: SchemaFieldType {
    /// Encodes the schema field into an SQL string
    public func makeSchemaFieldTypeString() -> String {
        return self.name + self.lengthName
    }
    
    /// Return the MySQL types used by default for the primary types
    public static func makeSchemaFieldType(for type: Any.Type) -> ColumnType? {
        switch id(type) {
        case id(Int.self):
            #if arch(x86_64) || arch(arm64)
                return .int64()
            #else
                return .int32()
            #endif
        case id(Int8.self): return .int8()
        case id(Int16.self): return .int16()
        case id(Int32.self): return .int32()
        case id(Int64.self): return .int64()
        case id(UInt.self):
            #if arch(x86_64) || arch(arm64)
                return .uint64()
            #else
                return .uint32()
            #endif
        case id(UInt8.self): return .uint8()
        case id(UInt16.self): return .uint16()
        case id(UInt32.self): return .uint32()
        case id(UInt64.self): return .uint64()
        case id(String.self): return .varChar(length: 255)
        case id(Bool.self): return .uint8()
        case id(Date.self): return .datetime()
        case id(Double.self): return .double()
        case id(Float32.self): return .float()
        case id(UUID.self): return .varChar(length: 64, binary: true)
        default: return nil
        }
    }
}

fileprivate func id(_ type: Any.Type) -> ObjectIdentifier {
    return ObjectIdentifier(type)
}

extension SchemaQuery: MySQLQuery {
    /// Serializes the Schema query into a MySQL query string
    public var queryString: String {
        return MySQLSerializer().serialize(schema: self)
    }
}
