extension SQLSerializer {
    public func serialize(predicateGroup: DataPredicateGroup) -> String {
        let method = serialize(predicateGroupRelation: predicateGroup.relation)
        let group = predicateGroup.predicates.map(serialize).joined(separator: " \(method) ")
        return "(" + group + ")"
    }

    public func serialize(predicateGroupRelation: DataPredicateGroupRelation) -> String {
        switch predicateGroupRelation {
        case .and: return "AND"
        case .or: return "OR"
        }
    }

    public func serialize(predicateItem: DataPredicateItem) -> String {
        switch predicateItem {
        case .group(let group): return serialize(predicateGroup: group)
        case .predicate(let predicate): return serialize(predicate: predicate)
        }
    }

    public func serialize(predicate: DataPredicate) -> String {
        var statement: [String] = []

        let escapedColumn = makeEscapedString(from: predicate.column.name)

        if let table = predicate.column.table {
            let escaped = makeEscapedString(from: table)
            statement.append("\(escaped).\(escapedColumn)")
        } else {
            statement.append(escapedColumn)
        }

        statement.append(serialize(comparison: predicate.comparison))

        switch predicate.value {
        case .column(let col):
            statement.append(serialize(column: col))
        case .subquery(let subquery):
            let sub = serialize(data: subquery)
            statement.append("(" + sub + ")")
        case .placeholder:
            statement.append(makePlaceholder(predicate: predicate))
        case .placeholderArray(let length):
            var placeholders: [String] = []
            for _ in 0..<length {
                placeholders.append(makePlaceholder(predicate: predicate))
            }
            statement.append("(" + placeholders.joined(separator: ", ") + ")")
        case .none:
            break
        }

        return statement.joined(separator: " ")
    }

    public func makePlaceholder(predicate: DataPredicate) -> String {
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

    public func serialize(comparison: DataPredicateComparison) -> String {
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
