import Async
import Fluent
import FluentSQL
import Foundation
import SQLite

extension SQLiteConnection: SchemaSupporting, ReferenceSupporting {
    /// See SchemaSupporting.FieldType
    public typealias FieldType = SQLiteFieldType

    /// See SchemaExecutor.execute()
    public func execute(schema: DatabaseSchema) -> Future<Void> {
        return Future {
            guard schema.removeReferences.count <= 0 else {
                throw FluentSQLiteError(identifier: "foreignkeys-unsupported", reason: "SQLite does not support deleting foreign keys")
            }

            let schemaQuery = schema.makeSchemaQuery()

            let string = SQLiteSQLSerializer()
                .serialize(schema: schemaQuery)

            return self.query(string: string).execute().map(to: Void.self) { results in
                assert(results == nil)
            }
        }
    }
    
    /// ReferenceSupporting.enableReferences
    public func enableReferences() -> Future<Void> {
        return query(string: "PRAGMA foreign_keys = ON;").execute().map(to: Void.self) { results in
            assert(results == nil)
        }
    }

    /// ReferenceSupporting.disableReferences
    public func disableReferences() -> Future<Void> {
        return query(string: "PRAGMA foreign_keys = OFF;").execute().map(to: Void.self) { results in
            assert(results == nil)
        }
    }
}

extension SQLiteFieldType: SchemaFieldType {
    /// See SchemaFieldType.makeSchemaFieldTypeString
    public func makeSchemaFieldTypeString() -> String {
        switch self {
        case .blob: return "BLOB"
        case .integer: return "INTEGER"
        case .real: return "REAL"
        case .text: return "TEXT"
        case .null: return "NULL"
        }
    }

    /// See SchemaFieldType.makeSchemaField
    public static func makeSchemaFieldType<T>(for type: T.Type) -> SQLiteFieldType? {
        switch id(T.self) {
        case id(Date.self), id(Double.self), id(Float.self): return .real
        case id(Int.self), id(UInt.self): return .integer
        case id(String.self): return .text
        case id(UUID.self), id(Data.self): return .blob
        default: return nil
        }
    }
}

fileprivate func id<T>(_ type: T.Type) -> ObjectIdentifier {
    return ObjectIdentifier(T.self)
}
