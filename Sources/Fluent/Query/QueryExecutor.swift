import Async

public protocol QueryExecutor {
    /// Executes the supplied query on the database connection.
    /// The returned future will be completed when the query is complete.
    /// Results will be outputed through the query's output stream.
    func execute<I: InputStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) -> Future<Void> where I.Input == D
}

// Convenience
extension QueryExecutor {
    public func makeQuery<M>(for type: M.Type = M.self) -> QueryBuilder<M> {
        return QueryBuilder(on: self)
    }
}
