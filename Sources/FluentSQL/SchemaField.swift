import Fluent
import SQL

extension SchemaField {
    /// Convert a schema field to a sql schema column.
    internal func makeSchemaColumn() -> SchemaColumn {
        return SchemaColumn(
            name: name,
            dataType: type.makeDataType(),
            isNotNull: !isOptional,
            isPrimaryKey: isIdentifier
        )
    }
}

extension SchemaFieldType {
    /// Convert a schema field type to a sql data type string
    internal func makeDataType() -> SchemaDataType {
        switch self {
        case .string(let length): return .varchar(length ?? 255)
        case .int: return .integer(19) // bigint default
        case .double: return .float(16) // double precision default
        case .data(let length): return .varbinary(length)
        case .date: return .date
        case .custom(let custom): return .custom(custom)
        }
    }
}
