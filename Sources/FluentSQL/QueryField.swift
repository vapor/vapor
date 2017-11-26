import Fluent
import SQL

extension QueryField {
    /// Convert query field to sql data column.
    internal func makeDataColumn() -> DataColumn {
        return DataColumn(table: entity, name: name)
    }
}
