import Fluent
import SQL

extension SchemaField {
    /// Convert a schema field to a sql schema column.
    internal func makeSchemaColumn() -> SchemaColumn {
        return SchemaColumn(
            name: name,
            dataType: type,
            isNotNull: !isOptional,
            isPrimaryKey: isIdentifier
        )
    }
}
