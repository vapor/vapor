import Async

/// Types conforming to this protocol can be used
/// as a Fluent database connection for executing queries.
public protocol Connection: QuerySupporting, ConnectionRepresentable {}

/// Capable of being represented as a database connection
/// for the supplied identifier.
public protocol ConnectionRepresentable {
    /// Create a database connection for the supplied dbid.
    func makeConnection<D>(_ database: DatabaseIdentifier<D>) -> Future<D.Connection>
}
