import Async

/// A database transaction. Work done inside the
/// transaction's closure will be rolled back if
/// any errors are thrown.
public struct DatabaseTransaction<Connection: DatabaseConnection> {
    /// Closure for performing the transaction.
    public typealias Closure = (Connection) throws -> Future<Void>

    /// Contains the transaction's work.
    public let closure: Closure

    /// Runs the transaction on a connection.
    public func run(on conn: Connection) -> Future<Void> {
        return Future {
            return try self.closure(conn)
        }
    }
}
