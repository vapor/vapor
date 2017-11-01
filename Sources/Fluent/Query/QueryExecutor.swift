import Async

/// Capable of executing a database query.
public protocol QueryExecutor {
    /// Executes the supplied query on the database connection.
    /// The returned future will be completed when the query is complete.
    /// Results will be outputed through the query's output stream.
    func execute<I: InputStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) -> Future<Void> where I.Input == D
}

/// Creates a database query using this executor.
///
/// If this request does not have a connection,
/// a new connection will be requested from the worker's
/// connection pool and cached to the request.
///
/// Subsequent calls to this function will use the same connection.
extension QueryExecutor {
    public func query<M>(_ type: M.Type = M.self) -> QueryBuilder<M> {
        return QueryBuilder(on: self)
    }
}

// MARK: temporary, fixme w/ conditional conformance.
extension Future: QueryExecutor {
    /// See QueryExecutor.execute
    public func execute<I: InputStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) -> Future<Void> where I.Input == D {
        return self.then { result in
            guard let executor = result as? QueryExecutor else {
                throw "future not query executor type"
            }

            return executor.execute(query: query, into: stream)
        }
    }
}
