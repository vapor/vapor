/// http://localhost:8000/mysql/basics/#queries
public protocol Query {
    /// Returns this query represented as a String
    var string: String { get }
}

extension String : Query {
    /// String is the query itself
    public var string: String {
        return self
    }
}
