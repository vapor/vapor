public struct SchemaQuery {
    public var statement: SchemaStatement
    public var table: String

    public init(
        statement: SchemaStatement,
        table: String
    ) {
        self.statement = statement
        self.table = table
    }
}
