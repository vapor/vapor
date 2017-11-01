import Async
import SQLite

extension SQLiteConnection: TransactionExecutor {
    public func execute(transaction: DatabaseTransaction) -> Future<Void> {
        let promise = Promise(Void.self)

        makeQuery("BEGIN TRANSACTION").execute().then {_ in
            transaction.closure(self).then {
                print("transaction done")
                self.makeQuery("COMMIT TRANSACTION")
                    .execute()
                    .chain(to: promise)
                }.catch { err in
                    self.makeQuery("ROLLBACK TRANSACTION").execute().then { query in
                        print("rollback success")
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
