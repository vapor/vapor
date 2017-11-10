import Async

/// Capable of executing a database query.
public protocol QuerySupporting {
    /// Executes the supplied query on the database connection.
    /// The returned future will be completed when the query is complete.
    /// Results will be outputed through the query's output stream.
    func execute<I: InputStream & ClosableStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) where I.Input == D
}

/// Creates a database query using this executor.
///
/// If this request does not have a connection,
/// a new connection will be requested from the worker's
/// connection pool and cached to the request.
///
/// Subsequent calls to this function will use the same connection.
extension Connection {
    public func query<Model>(_ type: Model.Type = Model.self) -> QueryBuilder<Model>
        where Model.Database.Connection == Self
    {
        return QueryBuilder(on: self)
    }
}
