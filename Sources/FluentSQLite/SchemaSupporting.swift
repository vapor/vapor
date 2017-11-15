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
        return then {
            guard schema.removeReferences.count <= 0 else {
                throw "SQLite does not support deleting foreign keys"
            }

            let schemaQuery = schema.makeSchemaQuery()

            let string = SQLiteSQLSerializer()
                .serialize(schema: schemaQuery)

            return self.query(string: string).execute()
        }
    }

    /// See SchemaSupporting.SchemaFieldType
    public typealias SchemaFieldType = SQLiteFieldType

    /// ReferenceSupporting.enableReferences
    public func enableReferences() -> Future<Void> {
        print("enabled")
        return query(string: "PRAGMA foreign_keys = ON;").execute()
    }

    /// ReferenceSupporting.disableReferences
    public func disableReferences() -> Future<Void> {
        return query(string: "PRAGMA foreign_keys = OFF;").execute()
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
    public static func makeSchemaFieldType(for basicFieldType: BasicSchemaFieldType) -> SQLiteFieldType {
        switch basicFieldType {
        case .date: return Date.makeSchemaFieldType()
        case .double: return Double.makeSchemaFieldType()
        case .int: return Int.makeSchemaFieldType()
        case .string: return String.makeSchemaFieldType()
        case .uuid: return UUID.makeSchemaFieldType()
        }
    }
}

extension String: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> SQLiteFieldType {
        return .text
    }
}

extension Int: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> SQLiteFieldType {
        return .integer
    }
}

extension Date: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> SQLiteFieldType {
        return .real
    }
}

extension Double: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> SQLiteFieldType {
        return .real
    }
}

extension UUID: SchemaFieldTypeRepresentable {
    /// See SQLiteFieldTypeRepresentable.makeSchemaFieldType
    public static func makeSchemaFieldType() -> SQLiteFieldType {
        return .blob
    }
}

