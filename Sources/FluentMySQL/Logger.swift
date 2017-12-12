import Async
import MySQL

/// A MySQL logger.
public protocol MySQLLogger {
    /// Log the query.
    func log(query: MySQLQuery) -> Completable
}

extension DatabaseLogger: MySQLLogger {
    /// See MySQLLogger.log
    public func log(query: MySQLQuery) -> Completable {
        let log = DatabaseLog(query: query.queryString)
        return record(log: log)
    }
}
