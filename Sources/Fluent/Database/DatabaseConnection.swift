import Async

/// Types conforming to this protocol can be used
/// as a Fluent database connection for executing queries.
public protocol Connection: QuerySupporting, ConnectionRepresentable {}

/// Capable of being represented as a database connection
/// for the supplied identifier.
public protocol ConnectionRepresentable {
    /// Create a database connection for the supplied dbid.
    func makeConnection<D>(to database: DatabaseIdentifier<D>) -> Future<D.Connection>
}

extension Connection {
    /// Create a query for the specified model using this connection.
    public func query<M>(_ model: M.Type) -> QueryBuilder<M>
        where M.Database.Connection == Self
    {
        return QueryBuilder(M.self, on: Future(self))
    }
}
