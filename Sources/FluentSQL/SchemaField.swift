import Fluent
import SQL

extension SchemaField {
    /// Convert a schema field to a sql schema column.
    internal func makeSchemaColumn(delegate: SchemaDelegate) -> SchemaColumn {
        return SchemaColumn(
            name: name,
            dataType: delegate.convertToDataType(type),
            isNotNull: !isOptional,
            isPrimaryKey: isIdentifier
        )
    }
}
