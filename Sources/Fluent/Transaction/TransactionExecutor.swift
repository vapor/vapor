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

// MARK: temporary, fixme w/ conditional conformance.
extension Future: TransactionExecutor {
    /// See TransactionExecutor.execute
    public func execute(transaction: DatabaseTransaction) -> Future<Void> {
        return then { result in
            guard let executor = result as? TransactionExecutor else {
                throw "future not query executor type"
            }
            
            return executor.execute(transaction: transaction)
        }
    }
}
