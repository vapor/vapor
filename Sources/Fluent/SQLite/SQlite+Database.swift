import Async
import SQLite

extension SQLiteDatabase: Database {
    public func makeConnection(
        on worker: Worker
    ) -> Future<DatabaseConnection> {
        let sqlite: Future<SQLiteConnection> = makeConnection(on: worker)
        return sqlite.map { $0 }
    }
}

extension SQLiteConnection: DatabaseConnection { }

