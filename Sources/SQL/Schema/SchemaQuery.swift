public struct SchemaQuery {
    public var statement: SchemaStatement
    public var table: String
    public var columns: [SchemaColumn]

    public init(
        statement: SchemaStatement,
        table: String,
        columns: [SchemaColumn] = []
    ) {
        self.statement = statement
        self.table = table
        self.columns = columns
    }
}
