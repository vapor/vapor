extension SQLSerializer {
    public func serialize(data query: DataQuery) -> String {
        let table = makeEscapedString(from: query.table)
        var statement: [String] = []

        switch query.statement {
        case .delete:
            statement.append("DELETE FROM")
            statement.append(table)
        case .insert:
            statement.append("INSERT INTO")
            statement.append(table)

            let columns = query.columns.map { makeEscapedString(from: $0.name) }
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
            statement.append(table)
        case .update:
            statement.append("UPDATE")
            statement.append(table)

            let columns = query.columns.map { serialize(column: $0) }
            let set = columns.map { "SET \($0) = " + makePlaceholder(name: $0) }
            statement.append(set.joined(separator: ", "))
        }

        if !query.predicates.isEmpty {
            statement.append("WHERE")

            let serializedPredicates = query.predicates.map { serialize(predicate: $0) }
            statement.append(serializedPredicates.joined(separator: " AND "))
        }

        return statement.joined(separator: " ")
    }
}
