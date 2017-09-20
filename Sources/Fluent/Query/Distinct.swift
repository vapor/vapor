extension QueryRepresentable  where Self: ExecutorRepresentable {
    /// Limits results to be distinct values
    public func distinct() throws -> Query<E> {
        let query = try makeQuery()
        query.isDistinct = true
        return query
    }
}
