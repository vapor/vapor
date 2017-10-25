extension SQLSerializer {
    public func serialize(query: SQLQuery) -> String {
        switch query {
        case .schema(let schema):
            return serialize(schema: schema)
        case .data(let data):
            return serialize(data: data)
        }
    }
}
