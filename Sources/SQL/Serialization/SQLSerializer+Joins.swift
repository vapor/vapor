extension SQLSerializer {
    public func serialize(joins: [Join]) -> String {
        return joins.map(serialize).joined(separator: " ")
    }

    public func serialize(join: Join) -> String {
        var statement: [String] = []
        statement.append("JOIN")

        let foreignTable = makeEscapedString(from: join.foreignTable)
        statement.append(foreignTable)
        statement.append("ON")

        let localColumn = DataColumn(table: join.table, name: join.column)
        statement.append(serialize(column: localColumn))

        statement.append("=")

        let foreignColumn = DataColumn(table: join.foreignTable, name: join.foreignColumn)
        statement.append(serialize(column: foreignColumn))

        return statement.joined(separator: " ")
    }
}
