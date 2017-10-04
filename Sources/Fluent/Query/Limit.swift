/// Limits the count of results
/// returned by the `Query`
public struct Limit {
    /// The maximum number of
    /// results to be returned.
    public let count: Int

    /// The number of entries to offset the
    /// query by.
    public let offset: Int

    public init(count: Int, offset: Int = 0) {
        self.count = count
        self.offset = offset
    }
}

extension QueryRepresentable where Self: ExecutorRepresentable {
    /// Limits the count of results returned
    /// by the `Query`.
    @discardableResult
    public func limit(_ count: Int, offset: Int = 0) throws -> Query<E> {
        let query = try makeQuery()
        let limit = Limit(count: count, offset: offset)
        try query.limit(limit)
        return query
    }
    
    @discardableResult
    public func limit(_ limit: Limit) throws -> Query<E> {
        let query = try makeQuery()
        query.limits = [.some(limit)]
        return query
    }
}
