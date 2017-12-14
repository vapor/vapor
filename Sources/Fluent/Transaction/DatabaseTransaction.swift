import Async

/// A database transaction. Work done inside the
/// transaction's closure will be rolled back if
/// any errors are thrown.
public struct DatabaseTransaction<Connection: DatabaseConnection> {
    /// Closure for performing the transaction.
    public typealias Closure = (Connection) throws -> Signal

    /// Contains the transaction's work.
    public let closure: Closure

    /// Runs the transaction on a connection.
    public func run(on conn: Connection) -> Signal {
        return Signal {
            return try self.closure(conn)
        }
    }
}
