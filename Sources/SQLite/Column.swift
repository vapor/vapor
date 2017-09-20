import CSQLite

/// A SQLite column. One instance of each column is created per
/// result set and all rows will point to the same column instance.
public final class Column {
    /// The columns string name.
    public var name: String

    /// Create a column from a statement pointer and offest.
    init(statement: Statement, offset: Int32) throws {
        guard let nameRaw = sqlite3_column_name(statement.raw, offset) else {
            throw Error(problem: .error, reason: "Unexpected nil column name")
        }
        self.name = String(cString: nameRaw)
    }
}
