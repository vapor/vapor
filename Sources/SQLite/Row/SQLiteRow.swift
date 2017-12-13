import CSQLite

/// A SQlite row of data. This contains one or more Fields.
public struct SQLiteRow {
    /// The row's fields, stored by column name for O(1) access.
    public var fields: [SQLiteColumn: SQLiteField]

    /// Create a new row with fields.
    public init(fields: [SQLiteColumn: SQLiteField] = [:]) {
        self.fields = fields
    }

    /// Access the row by field name, returning optional Data.
    public subscript(_ field: String) -> SQLiteData? {
        get {
            let col = SQLiteColumn(name: field)
            guard let field = fields[col] else {
                return nil
            }

            return field.data
        }
        set {
            let col = SQLiteColumn(name: field)
            if let value = newValue {
                fields[col] = SQLiteField(data: value)
            } else {
                fields.removeValue(forKey: col)
            }
        }
    }
}
