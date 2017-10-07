/// Capable of serializing a Fluent Query
/// into SQL.
public protocol SQLSerializer {

}

extension SQLSerializer {
    public func makePlaceholder(name: String) -> String {
        return "?"
    }

    public func makeEscapedString(from string: String) -> String {
        return "`\(string)`"
    }

    public func serialize(predicate: Predicate) -> String {
        var statement: [String] = []

        let escapedColumn = makeEscapedString(from: predicate.column)

        if let table = predicate.table {
            let escaped = makeEscapedString(from: table)
            statement.append("\(escaped).\(escapedColumn)")
        } else {
            statement.append(escapedColumn)
        }

        switch predicate.comparison {
        case .equal:
            statement.append("=")
            statement.append(makePlaceholder(name: predicate.column))
        default:
            fatalError("not implemented")
        }

        return statement.joined(separator: " ")
    }


    public func serialize(computed: DataComputed) -> String {
        var serialized = computed.function
        serialized += "("
        if computed.columns.isEmpty {
            serialized += "*"
        } else {
            let cols = computed.columns.map { serialize(column: $0) }
            serialized += cols.joined(separator: ", ")
        }
        serialized += ")"
        if let key = computed.key {
            serialized += " as " + makeEscapedString(from: key)
        }
        return serialized
    }

    public func serialize(column: DataColumn) -> String {
        let escapedName = makeEscapedString(from: column.name)
        if let table = column.table {
            let escapedTable = makeEscapedString(from: table)
            return "\(escapedTable).\(escapedName)"
        } else {
            return escapedName
        }
    }

    public func serialize(query: DataQuery) -> String {
        let table = makeEscapedString(from: query.table)

        var statement: [String] = []


        switch query.statement {
        case .delete:
            statement.append("DELETE FROM")
        case .insert:
            statement.append("INSERT INTO")

            let columns = query.columns.map { serialize(column: $0) }
            statement.append("(" + columns.joined(separator: ", ") + ")")
            statement.append("VALUES")

            let placeholders = query.columns.map { makePlaceholder(name: $0.name) }
            statement.append("(" + placeholders.joined(separator: ", ") + ")")
        case .select:
            statement.append("SELECT")

            var columns: [String] = []

            if !query.computed.isEmpty {
                columns += query.computed.map { serialize(computed: $0) }
            }
            
            if columns.isEmpty {
                columns += ["\(table).*"]
            } else {
                columns += query.columns.map { serialize(column: $0) }
            }

            statement.append(columns.joined(separator: ", "))

            statement.append("FROM")
        case .update:
            statement.append("UPDATE")

            let columns = query.columns.map { serialize(column: $0) }
            let set = columns.map { "SET \($0) = " + makePlaceholder(name: $0) }
            statement.append(set.joined(separator: ", "))
        }

        statement.append(table)

        if !query.predicates.isEmpty {
            statement.append("WHERE")

            let serializedPredicates = query.predicates.map { serialize(predicate: $0) }
            statement.append(serializedPredicates.joined(separator: " AND "))
        }

        return statement.joined(separator: " ")
    }

    public func serialize(query: SQLQuery) -> String {
        switch query {
        case .schema(let schema):
            fatalError("Not implemented")
        case .data(let data):
            return serialize(query: data)
        case .transaction(let trans):
            fatalError("Not implemented")
        }
    }
}

