import SQL

/// A SQLite flavored SQL serializer.
public final class SQLiteSQLSerializer: SQLSerializer {
    public init() { }

    /// See SQLSerializer.serialize(dataType:)
    public func serialize(dataType: SchemaDataType) -> String {
        switch dataType {
        case .varchar, .character, .timestamp: return "TEXT"
        case .integer, .boolean: return "INTEGER"
        case .float, .decimal: return "REAL"
        case .varbinary, .binary, .array, .multiset, .xml: return "BLOB"
        case .date, .time, .interval: return "REAL"
        case .custom(let s): return s
        }
    }
}
