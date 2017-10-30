/// Defines a Fluent query limit and offset.
public struct Limit {
    /// The maximum number of items to include
    /// in the query response.
    public var count: Int

    /// The amount by which to offset the query results.
    /// For example, if offset is 1, the first result in the
    /// query response will be the second result of the actual data set.
    public var offset: Int

    /// Creates a new limit with a count and offset.
    /// See Limit.count and Limit.offset.
    public init(count: Int, offset: Int = 0) {
        self.count = count
        self.offset = offset
    }
}

extension QueryBuilder {
    /// Convenience for applying a limit to the query.
    /// See Limit.init()
    public func limit(_ count: Int, offset: Int = 0) -> Self {
        let limit = Limit(count: count, offset: offset)
        query.limit = limit
        return self
    }
}
