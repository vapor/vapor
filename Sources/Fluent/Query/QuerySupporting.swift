import Async

/// Capable of executing a database query.
public protocol QuerySupporting {
    /// Executes the supplied query on the database connection.
    /// The returned future will be completed when the query is complete.
    /// Results will be outputed through the query's output stream.
    func execute<I: InputStream, D: Decodable>(
        query: DatabaseQuery,
        into stream: I
    ) where I.Input == D

    /// Returns the last auto-incremented ID.
    var lastAutoincrementID: Int? { get }
}
