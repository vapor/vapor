import CSQLite

/// The type of a certain field. This determines how the field's data should be parsed.
/// Note: The field type is not directly tied to the column type, and can vary between rows.
public enum FieldType {
    case integer
    case float
    case text
    case blob
    case null

    /// Create a new field type from statement and an offset.
    init(statement: Query, offset: Int32) throws {
        switch sqlite3_column_type(statement.raw, offset) {
        case SQLITE_INTEGER:
            self = .integer
        case SQLITE_FLOAT:
            self = .float
        case SQLITE_TEXT:
            self = .text
        case SQLITE_BLOB:
            self = .blob
        case SQLITE_NULL:
            self = .null
        default:
            throw SQLiteError(problem: .error, reason: "Unexpected column type.")
        }
    }
}
