import libc
import Console

/**
    Logs to the console

    - parameter level: LogLevel enum
    - parameter message: String to log
*/
public class ConsoleLogger: Log {
    let console: ConsoleProtocol

    public var enabled: [LogLevel]

    /**
        Creates an instance of `ConsoleLogger`
        with the desired `Console`.
    */
    public init(console: ConsoleProtocol) {
        self.console = console
        enabled = LogLevel.all
    }

    /**
        The basic log function of the console.

        - parameter level: the level with which to filter
        - parameter message: the message to log to console
     */
    public func log(_ level: LogLevel, message: String) {
        if enabled.contains(level) {
            console.output(message, style: level.consoleStyle)
        }
    }
}

extension LogLevel {
    var consoleStyle: ConsoleStyle {
        switch self {
        case .debug, .verbose, .custom(_):
            return .plain
        case .info:
            return .info
        case .warning:
            return .warning
        case .error, .fatal:
            return .error
        }
    }
}
