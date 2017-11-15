import CSQLite

/// The type of a certain field. This determines how the field's data should be parsed.
/// Note: The field type is not directly tied to the column type, and can vary between rows.
public enum SQLiteFieldType {
    case integer
    case real
    case text
    case blob
    case null

    /// Create a new field type from statement and an offset.
    init(query: SQLiteQuery.Raw, offset: Int32) throws {
        switch sqlite3_column_type(query, offset) {
        case SQLITE_INTEGER:
            self = .integer
        case SQLITE_FLOAT:
            self = .real
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
