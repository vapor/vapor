extension URI {
    public mutating func append(query appendQuery: StructuredData) {
        guard let object = appendQuery.object where !object.isEmpty else { return }
        let appendQuery = object
            .flatMap { key, value in
                guard let string = value.string else { return nil }
                return "\(key)=\(string)"
            }
            .joined(separator: "&")

        var new = ""
        if let existing = query {
            new += existing
            new += "&"
        }
        new += appendQuery

        query = new
    }
}
