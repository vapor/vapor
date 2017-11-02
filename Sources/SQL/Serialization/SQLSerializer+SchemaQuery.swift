extension SQLSerializer {
    /// See SQLSerializer.serialize(schema:)
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

    /// See SQLSerializer.serialize(column:)
    public func serialize(column: SchemaColumn) -> String {
        var sql: [String] = []

        let name = makeEscapedString(from: column.name)
        sql.append(name)

        sql.append(serialize(dataType: column.dataType))

        if column.isPrimaryKey {
            sql.append("PRIMARY KEY")
        } else if column.isNotNull {
            sql.append("NOT NULL")
        }

        return sql.joined(separator: " ")
    }

    /// See SQLSerializer.serialize(dataType:)
    public func serialize(dataType: SchemaDataType) -> String {
        switch dataType {
        case .character(let n): return "CHARACTER(\(n))"
        case .varchar(let n): return "VARCHAR(\(n))"
        case .binary(let n): return "BINARY(\(n))"
        case .boolean: return "BOOLEAN"
        case .varbinary(let n): return "VARBINARY(\(n))"
        case .integer(let p): return "INTEGER(\(p))"
        case .decimal(let p, let s): return "DECIMAL(\(p),\(s))"
        case .float(let p): return "FLOAT(\(p))"
        case .date: return "DATE"
        case .time: return "TIME"
        case .timestamp: return "TIMESTAMP"
        case .interval: return "INTERVAL"
        case .array: return "ARRAY"
        case .multiset: return "MULTISET"
        case .xml: return "XML"
        case .custom(let s): return s
        }

    }
}
