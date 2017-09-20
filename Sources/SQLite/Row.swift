import CSQLite

/// A SQlite row of data. This contains one or more Fields.
public struct Row {
    /// The row's fields, stored by column name for O(1) access.
    public var fields: [String: Field]

    /// Create a new row with fields.
    init(fields: [String: Field] = [:]) {
        self.fields = fields
    }

    /// Access the row by field name, returning optional Data.
    public subscript(_ field: String) -> Data? {
        guard let field = fields[field] else {
            return nil
        }
        
        return field.data
    }
}
