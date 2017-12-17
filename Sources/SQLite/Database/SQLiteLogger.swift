import Async

/// A SQLite logger.
public protocol SQLiteLogger {
    /// Log the query.
    func log(query: SQLiteQuery) -> Future<Void>
}
