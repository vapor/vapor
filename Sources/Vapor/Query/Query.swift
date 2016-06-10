class Query {
    static func parse(_ query: String) -> StructuredData {
        return FormURLEncoded.parse(query.data)
    }
}
