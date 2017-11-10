import Async
import Fluent
import SQLite

extension SQLiteDatabase: Database { }

extension SQLiteConnection: Connection { }

extension SQLiteDatabase: LogSupporting {
    /// See SupportsLogging.enableLogging
    public func enableLogging(using logger: DatabaseLogger) {
        self.logger = logger
    }
}

extension DatabaseLogger: SQLiteLogger {
    /// See SQLiteLogger.log
    public func log(query: SQLiteQuery) -> Future<Void> {
        let log = DatabaseLog(
            query: query.string,
            values: query.binds.map { $0.description }
        )
        return record(log: log)
    }
}
