extension SQLSerializer {
    public func serialize(schema query: SchemaQuery) -> String {
        var statement: [String] = []
        let table = makeEscapedString(from: query.table)

        switch query.statement {
        case .create(let columns):
            statement.append("CREATE TABLE")
            statement.append(table)

            let columns = columns.map { serialize(column: $0) }
            statement.append("(" + columns.joined(separator: ", ") + ")")
        case .alter(let columns, let deleteColumns):
            statement.append("ALTER TABLE")
            statement.append(table)

            let adds = columns.map { "ADD " + serialize(column: $0) }
            if adds.count > 0 {
                statement.append(adds.joined(separator: ", "))
            }

            let deletes = deleteColumns.map { "DROP " + makeEscapedString(from: $0) }
            if deletes.count > 0 {
                statement.append(deletes.joined(separator: ", "))
            }
        case .drop:
            statement.append("DROP TABLE")
            statement.append(table)
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
