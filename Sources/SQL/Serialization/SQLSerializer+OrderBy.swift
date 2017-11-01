extension SQLSerializer {
    public func serialize(orderBys: [OrderBy]) -> String {
        var statement: [String] = []

        statement.append("ORDER BY")
        statement.append(orderBys.map(serialize).joined(separator: ", "))

        return statement.joined(separator: " ")
    }

    public func serialize(orderBy: OrderBy) -> String {
        var statement: [String] = []

        let columns = orderBy.columns.map(serialize).joined(separator: ", ")
        statement.append(columns)

        statement.append(serialize(orderByDirection: orderBy.direction))
        return statement.joined(separator: " ")
    }

    public func serialize(orderByDirection: OrderByDirection) -> String {
        switch orderByDirection {
        case .ascending:
            return "ASC"
        case .descending:
            return "DESC"
        }
    }
}

