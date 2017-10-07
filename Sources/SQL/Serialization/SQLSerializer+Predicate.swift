extension SQLSerializer {
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
}
