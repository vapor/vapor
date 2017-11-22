import Foundation
import Async
import SQL
import Fluent
import FluentSQL
import MySQL

extension FluentMySQLConnection : SchemaSupporting, TransactionSupporting {
    /// Runs a transaction on the MySQL connection
    public func execute(transaction: DatabaseTransaction<FluentMySQLConnection>) -> Future<Void> {
        return connection.administrativeQuery("SET autocommit = 0; START TRANSACTION").flatMap {
            let promise = Promise<Void>()
            
            transaction.run(on: self).do {
                self.connection.administrativeQuery("COMMIT TRANSACTION").chain(to: promise)
            }.catch { error in
                self.connection.administrativeQuery("ROLLBACK TRANSACTION").do {
                    // still fail even though rollback succeeded
                    promise.fail(error)
                }.catch { error in
                    promise.fail(error)
                }
            }
            
            return promise.future
        }
    }
    
    public typealias FieldType = ColumnType
    
    /// Executes the schema query
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        let query = schema.makeSchemaQuery()
        _ = self.logger?.log(query: query)
        
        return connection.administrativeQuery(query)
    }
}

extension ColumnType : SchemaFieldType {
    /// Encodes the schema field into an SQL string
    public func makeSchemaFieldTypeString() -> String {
        return self.name + self.lengthName
    }
    
    /// Return the MySQL types used by default for the primary types
    public static func makeSchemaFieldType(for basicFieldType: BasicSchemaFieldType) -> ColumnType {
        switch basicFieldType {
        case .date: return .datetime()
        case .double: return .double()
        case .string: return .varChar(length: 255)
        case .uuid: return .varChar(length: 64, binary: true)
        case .int:
            #if arch(x86_64) || arch(arm64)
                return .int64()
            #else
                return .int32()
            #endif
        }
    }
}

extension SchemaQuery: MySQL.Query {
    /// Serializes the Schema query into a MySQL query string
    public var queryString: String {
        return MySQLSerializer().serialize(schema: self)
    }
}

extension String: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .varChar(length: 255)
    }
}

extension Int: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        #if arch(x86_64) || arch(arm64)
            return .int64()
        #else
            return .int32()
        #endif
    }
}

extension UInt: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        #if arch(x86_64) || arch(arm64)
            return .uint64()
        #else
            return .uint32()
        #endif
    }
}

extension Int8: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .int8()
    }
}

extension UInt8: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .uint8()
    }
}

extension Bool: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .uint8()
    }
}

extension Int16: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .int16()
    }
}

extension UInt16: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .uint16()
    }
}

extension Int32: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .int32()
    }
}

extension UInt32: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .uint32()
    }
}

extension Date: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .datetime()
    }
}

extension Double: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .double()
    }
}

extension Float32: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .float()
    }
}

extension UUID: SchemaFieldTypeRepresentable {
    /// Returns the ColumnType for this Swift type
    public static func makeSchemaFieldType() -> ColumnType {
        return .varChar(length: 16, binary: true)
    }
}
