extension SQLSerializer {
    public func serialize(predicates: [Predicate]) -> String {
        var statement: [String] = []

        statement.append("WHERE")
        statement.append(predicates.map(serialize).joined(separator: " AND "))

        return statement.joined(separator: " ")
    }

    public func serialize(predicate: Predicate) -> String {
        var statement: [String] = []

        let escapedColumn = makeEscapedString(from: predicate.column.name)

        if let table = predicate.column.table {
            let escaped = makeEscapedString(from: table)
            statement.append("\(escaped).\(escapedColumn)")
        } else {
            statement.append(escapedColumn)
        }

        statement.append(serialize(comparison: predicate.comparison))

        switch predicate.comparison {
        case .in(let query):
            let sub = self.serialize(data: query)
            statement.append("(" + sub + ")")
        case .notIn(let query):
            let sub = self.serialize(data: query)
            // FIXME: needs a subset enum that can be either
            // number of placeholders or a subquery
            statement.append("(" + sub + ")")
        case .null, .notNull:
            break
        default:
            statement.append(makePlaceholder(predicate: predicate))
        }

        return statement.joined(separator: " ")
    }

    public func makePlaceholder(predicate: Predicate) -> String {
        var statement: [String] = []

        switch predicate.comparison {
        case .between:
            statement.append(makePlaceholder(name: predicate.column.name + ".min"))
            statement.append("AND")
            statement.append(makePlaceholder(name: predicate.column.name + ".max"))
        default:
            statement.append(makePlaceholder(name: predicate.column.name))
        }

        return statement.joined(separator: " ")
    }

    public func serialize(comparison: PredicateComparison) -> String {
        switch comparison {
        case .equal: return "="
        case .notEqual: return "!="
        case .lessThan: return "<"
        case .greaterThan: return ">"
        case .lessThanOrEqual: return "<="
        case .greaterThanOrEqual: return ">="
        case .`in`: return "IN"
        case .notIn: return "NOT IN"
        case .between: return "BETWEEN"
        case .like: return "LIKE"
        case .notLike: return "NOT LIKE"
        case .null: return "IS NULL"
        case .notNull: return "IS NOT NULL"
        }
    }
}
