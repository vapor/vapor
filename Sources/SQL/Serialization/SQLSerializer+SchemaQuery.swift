extension SQLSerializer {
    /// See SQLSerializer.serialize(schema:)
    public func serialize(schema query: SchemaQuery) -> String {
        var statement: [String] = []
        let table = makeEscapedString(from: query.table)

        switch query.statement {
        case .create(let columns, let foreignKeys):
            statement.append("CREATE TABLE")
            statement.append(table)

            let columns = columns.map { serialize(column: $0) }
                + foreignKeys.map { serialize(foreignKey: $0) }
            statement.append("(" + columns.joined(separator: ", ") + ")")
        case .alter(let columns, let deleteColumns, let deleteForeignKeys):
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

            let deleteFKs = deleteForeignKeys.map { "DROP FOREIGN KEY " + makeEscapedString(from: $0) }
            if deleteFKs.count > 0 {
                statement.append(deleteFKs.joined(separator: ", "))
            }
        case .drop:
            statement.append("DROP TABLE")
            statement.append(table)
        }

        return statement.joined(separator: " ")
    }

    /// See SQLSerializer.serialize(column:)
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

    public func serialize(foreignKey: SchemaForeignKey) -> String {
        // FOREIGN KEY(trackartist) REFERENCES artist(artistid) ON UPDATE action ON DELETE action
        var sql: [String] = []

        sql.append("FOREIGN KEY")

        if let table = foreignKey.local.table {
            sql.append(makeEscapedString(from: table))
        }
        sql.append("(" + makeEscapedString(from: foreignKey.local.name) + ")")

        sql.append("REFERENCES")

        if let table = foreignKey.foreign.table {
            sql.append(makeEscapedString(from: table))
        }
        sql.append("(" + makeEscapedString(from: foreignKey.foreign.name) + ")")
        sql.append("ON UPDATE \(foreignKey.onUpdate) ON DELETE \(foreignKey.onDelete)")

        return sql.joined(separator: " ")
    }
}
