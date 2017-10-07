extension SQLSerializer {
    public func serialize(schema query: SchemaQuery) -> String {
        var statement: [String] = []
        let table = makeEscapedString(from: query.table)

        switch query.statement {
        case .create:
            statement.append("CREATE TABLE")
            statement.append(table)

            let columns = query.columns.map { serialize(column: $0) }
            statement.append("(" + columns.joined(separator: ", ") + ")")
        default:
            fatalError("not supported")
        }

        return statement.joined(separator: " ")
    }

    public func serialize(column: SchemaColumn) -> String {
        var sql: [String] = []

        let name = makeEscapedString(from: column.name)
        sql.append(name)

        sql.append(column.dataType)

        if column.isPrimaryKey {
            sql.append("PRIMARY KEY")
        } else if column.isNotNull {
            sql.append("NOT NULL")
        }

        return sql.joined(separator: " ")
    }
}
