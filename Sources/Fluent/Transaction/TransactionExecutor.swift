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
        let promise = Promise(Void.self)

        self.then { result in
            if let executor = result as? TransactionExecutor {
                executor.execute(transaction: transaction)
                    .chain(to: promise)
            } else {
                promise.fail("future not query executor type")
            }
            }.catch(promise.fail)

        return promise.future
    }
}
