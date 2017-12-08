import Async
import Fluent
import SQLite

extension SQLiteDatabase: Database {
    public typealias Connection = SQLiteConnection
    
    public func makeConnection(from config: SQLiteConfig, on eventloop: EventLoop) -> Future<SQLiteConnection> {
        return self.makeConnection(on: eventloop)
    }
}

public struct SQLiteConfig {
    public init() {}
}

extension SQLiteConnection: DatabaseConnection {
    public typealias Config = SQLiteConfig
    
    public func connect<D>(to database: DatabaseIdentifier<D>) -> Future<D.Connection> {
        return then {
            guard let sqlite = self as? D.Connection else {
                throw "invalid connection type"
            }

            return Future(sqlite)
        }
    }
}

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
