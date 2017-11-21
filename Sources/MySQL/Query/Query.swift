/// [Learn More →](https://docs.vapor.codes/3.0/mysql/basics/#queries)
public protocol Query {
    /// Returns this query represented as a String
    var queryString: String { get }
}

extension String : Query {
    /// String is the query itself
    public var queryString: String {
        return self
    }
}
