/// Represents a SQL join.
public struct Join {
    public let method: JoinMethod
    public let table: String
    public let column: String
    public let foreignTable: String
    public let foreignColumn: String

    /// Create a new SQL join.
    public init(
        method: JoinMethod,
        table: String,
        column: String,
        foreignTable: String,
        foreignColumn: String
    ) {
        self.method = method
        self.table = table
        self.column = column
        self.foreignTable = foreignTable
        self.foreignColumn = foreignColumn
    }
}
