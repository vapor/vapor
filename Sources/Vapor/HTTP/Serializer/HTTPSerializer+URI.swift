extension URI {
    public mutating func append(query appendQuery: [String: String]) {
        var new = ""
        if let existing = query {
            new += existing
            new += "&"
        }
        new += appendQuery.map { key, val in "\(key)=\(val)" } .joined(separator: "&")
        query = new
    }
}
