import Async

/// Types conforming to this protocol can be used
/// as a Fluent database connection for executing queries.
public protocol DatabaseConnection {
    /// Executes the supplied query on the database connection.
    /// The returned future will be completed when the query is complete.
    /// Results will be outputed through the query's output stream.
    func execute<I: InputStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) -> Future<Void> where I.Input == D
}

// Convenience
extension DatabaseConnection {
    public func makeQuery<M>(for type: M.Type = M.self) -> QueryBuilder<M> {
        return QueryBuilder(on: self)
    }
}
