import Foundation
import Async
import SQL
import Fluent
import FluentSQL
import MySQL

extension DatabaseConnection : SchemaSupporting, TransactionSupporting {
    public func execute(transaction: DatabaseTransaction<DatabaseConnection>) -> Future<Void> {
        return connection.administrativeQuery("BEGIN TRANSACTION").flatMap {
            let promise = Promise<Void>()
            
            transaction.run(on: self).do {
                self.connection.administrativeQuery("COMMIT TRANSACTION").chain(to: promise)
            }.catch { error in
                self.connection.administrativeQuery("ROLLBACK TRANSACTION").do {
                    // still fail even tho rollback succeeded
                    promise.fail(error)
                }.catch { error in
                    promise.fail(error)
                }
            }
            
            return promise.future
        }
    }
    
    public typealias FieldType = Column.ColumnType
    
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        let query = schema.makeSchemaQuery()
        _ = self.logger?.log(query: query)
        
        return connection.administrativeQuery(query)
    }
}

extension Column.ColumnType : SchemaFieldType {
    public func makeSchemaFieldTypeString() -> String {
        return self.name + self.lengthName
    }
    
    public static func makeSchemaFieldType(for basicFieldType: BasicSchemaFieldType) -> Column.ColumnType {
        switch basicFieldType {
        case .date: return .datetime()
        case .double: return .double()
        case .int: return .int64()
        case .string: return .varChar(length: 256)
        case .uuid: return .varChar(length: 64, binary: true)
        }
    }
}

extension SchemaQuery: MySQL.Query {
    public var queryString: String {
        return MySQLSerializer().serialize(schema: self)
    }
}

extension String: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> Column.ColumnType {
        return .varChar(length: 256)
    }
}

extension Int: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> Column.ColumnType {
        #if arch(x86_64) || arch(arm64)
            return .int64()
        #else
            return .int32()
        #endif
    }
}

extension UInt: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> Column.ColumnType {
        #if arch(x86_64) || arch(arm64)
            return .uint64()
        #else
            return .uint32()
        #endif
    }
}

extension Date: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> Column.ColumnType {
        return .datetime()
    }
}

extension Double: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> Column.ColumnType {
        return .double()
    }
}

extension UUID: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> Column.ColumnType {
        return .varChar(length: 16, binary: true)
    }
}
