import Async
import SQLite

extension SQLiteConnection: TransactionExecutor {
    public func execute(transaction: DatabaseTransaction) -> Future<Void> {
        let promise = Promise(Void.self)

        SQLiteQuery(string: "BEGIN TRANSACTION", connection: self).execute().then {_ in
            transaction.closure(self).then {
                print("transaction done")
                SQLiteQuery(string: "COMMIT TRANSACTION", connection: self)
                    .execute()
                    .chain(to: promise)
                }.catch { err in
                    SQLiteQuery(string: "ROLLBACK TRANSACTION", connection: self).execute().then { query in
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
