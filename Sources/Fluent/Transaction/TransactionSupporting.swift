import Async

/// Capable of executing a database transaction.
public protocol TransactionSupporting: DatabaseConnection {
    /// Executes the supplied transaction on the db connection.
    func execute(transaction: DatabaseTransaction<Self>) -> Signal
}

extension TransactionSupporting {
    /// Convenience for executing a database transaction closure.
    public func transaction(
        _ closure: @escaping DatabaseTransaction<Self>.Closure
    ) -> Signal {
        let transaction = DatabaseTransaction(closure: closure)
        return execute(transaction: transaction)
    }
}
