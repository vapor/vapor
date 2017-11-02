extension SQLSerializer {
    /// See SQLSerializer.serialize(computed:)
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
}
