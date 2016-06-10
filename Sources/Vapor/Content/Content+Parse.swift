extension Content {
    static func parseQuery(uri: URI) -> StructuredData {
        var query: [String: StructuredData] = [:]

        uri.query.forEach { (key, values) in
            let string = values
                .flatMap { $0 }
                .joined(separator: ",")
            query[key] = .string(string)
        }

        return .dictionary(query)
    }
}
