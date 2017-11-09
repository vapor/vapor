import Async
import Fluent
import SQLite

extension SQLiteConnection: TransactionSupporting {
    /// See TransactionExecutor.execute
    public func execute(transaction: DatabaseTransaction<SQLiteConnection>) -> Future<Void> {
        let promise = Promise(Void.self)

        makeQuery("BEGIN TRANSACTION").execute().do {
            transaction.run(on: self).do {
                print("transaction done")
                self.makeQuery("COMMIT TRANSACTION")
                    .execute()
                    .chain(to: promise)
            }.catch { err in
                self.makeQuery("ROLLBACK TRANSACTION").execute().do { query in
                    // still fail even tho rollback succeeded
                    promise.fail(err)
                }.catch { err in
                    print("Rollback failed") // fixme: combine errors here
                    promise.fail(err)
                }
            }
        }.catch(promise.fail)

        return promise.future
    }
}
