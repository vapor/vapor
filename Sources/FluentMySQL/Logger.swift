import Async
import MySQL

/// A SQLite logger.
public protocol MySQLLogger {
    /// Log the query.
    func log(query: MySQL.Query) -> Future<Void>
}

extension DatabaseLogger: MySQLLogger {
    /// See SQLiteLogger.log
    public func log(query: MySQL.Query) -> Future<Void> {
        let log = DatabaseLog(query: query.queryString)
        return record(log: log)
    }
}
