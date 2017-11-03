import Async
import Foundation

/// Capable of logging queries through a supplied DatabaseLogger.
public protocol LogSupporting {
    /// Enables query logging to the supplied logger.
    func enableLogging(using logger: DatabaseLogger)
}

/// A database query, schema, tranasaction, etc logger.
public final class DatabaseLogger {
    /// A simple database logger that prints logs.
    public static var print: DatabaseLogger {
        return DatabaseLogger { log in
            Swift.print(log)
            return .done
        }
    }

    /// Closure for handling logs.
    public typealias LogHandler = (DatabaseLog) -> Future<Void>

    /// Current database log handler.
    public var handler: LogHandler

    /// Database identifier
    public var dbID: String

    /// Create a new database logger.
    public init(handler: @escaping LogHandler) {
        self.dbID = "fluent"
        self.handler = handler
    }

    /// Records a database log to the current handler.
    public func record(log: DatabaseLog) -> Future<Void> {
        var log = log
        log.dbID = dbID
        return handler(log)
    }
}
