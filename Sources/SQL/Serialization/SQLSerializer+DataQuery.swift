extension SQLSerializer {
    /// See SQLSerializer.serialize(data:)
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
            statement.append("SET")

            let columns = query.columns.map { makeEscapedString(from: $0.name) }
            let set = columns.map { "\($0) = " + makePlaceholder(name: $0) }
            statement.append(set.joined(separator: ", "))
        }

        if !query.joins.isEmpty {
            statement.append(serialize(joins: query.joins))
        }

        if !query.predicates.isEmpty {
            statement.append("WHERE")
            let group = DataPredicateGroup(relation: .and, predicates: query.predicates)
            statement.append(serialize(predicateGroup: group))
        }

        if !query.orderBys.isEmpty {
            statement.append(serialize(orderBys: query.orderBys))
        }

        if let limit = query.limit {
            statement.append("LIMIT \(limit)")
            if let offset = query.offset {
                statement.append("OFFSET \(offset)")
            }
        }

        return statement.joined(separator: " ")
    }
}
