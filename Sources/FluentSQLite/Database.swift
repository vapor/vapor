import Async
import Fluent
import SQLite
import Debugging

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
        return Future {
            guard let sqlite = self as? D.Connection else {
                throw FluentSQLiteError(identifier: "invalid-connection-type", reason: "The provided connection was not an SQLite connection")
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

/// Errors that can be thrown while working with FluentSQLite.
public struct FluentSQLiteError: Traceable, Debuggable, Swift.Error, Encodable {
    public static let readableName = "Fluent Error"
    public let identifier: String
    public var reason: String
    public var file: String
    public var function: String
    public var line: UInt
    public var column: UInt
    public var stackTrace: [String]
    
    init(
        identifier: String,
        reason: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = identifier
        self.reason = reason
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.stackTrace = FluentSQLiteError.makeStackTrace()
    }
}
