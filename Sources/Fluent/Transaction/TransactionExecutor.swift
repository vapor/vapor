import Async

/// Capable of executing a database transaction.
public protocol TransactionExecutor {
    /// Executes the supplied transaction on the db connection.
    func execute(transaction: DatabaseTransaction) -> Future<Void>
}

extension TransactionExecutor {
    /// Convenience for executing a database transaction closure.
    public func transaction(
        _ closure: @escaping DatabaseTransaction.Closure
    ) -> Future<Void> {
        let transaction = DatabaseTransaction(closure: closure)
        return execute(transaction: transaction)
    }
}
