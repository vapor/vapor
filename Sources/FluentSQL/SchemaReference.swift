import Fluent
import SQL

extension SchemaReference {
    /// Convert a schema reference to a sql foreign key
    internal func makeForeignKey() -> SchemaForeignKey {
        return SchemaForeignKey(
            name: "",
            local: DataColumn(table: nil, name: base.name),
            foreign: referenced.makeDataColumn(),
            onUpdate: onUpdate.rawValue,
            onDelete: onDelete.rawValue
        )
    }
}
