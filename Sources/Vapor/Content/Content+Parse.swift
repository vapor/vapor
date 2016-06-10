extension Content {
    static func parseQuery(uri: URI) -> StructuredData {
        guard let string = uri.query else {
            return .null
        }

        return FormURLEncoded.parse(string.data)
    }
}
