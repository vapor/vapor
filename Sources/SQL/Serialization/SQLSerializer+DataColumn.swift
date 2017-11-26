extension SQLSerializer {
    /// See SQLSerializer.serialize(column:)
    public func serialize(column: DataColumn) -> String {
        let escapedName = makeEscapedString(from: column.name)
        if let table = column.table {
            let escapedTable = makeEscapedString(from: table)
            return "\(escapedTable).\(escapedName)"
        } else {
            return escapedName
        }
    }
}
