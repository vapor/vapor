import Async
import MySQL

/// A MySQL logger.
public protocol MySQLLogger {
    /// Log the query.
    func log(query: MySQL.Query) -> Future<Void>
}

extension DatabaseLogger: MySQLLogger {
    /// See MySQLLogger.log
    public func log(query: MySQL.Query) -> Future<Void> {
        let log = DatabaseLog(query: query.queryString)
        return record(log: log)
    }
}
