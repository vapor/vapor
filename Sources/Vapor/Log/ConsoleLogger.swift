import libc
import Console

/**
    Logs to the console

    - parameter level: LogLevel enum
    - parameter message: String to log
*/
public class ConsoleLogger: LogProtocol {
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
        - parameter file: String where logging happens, is automatically set on default
        - parameter function: String where logging happens, is automatically set on default
        - parameter line: String where logging happens, is automatically set on default
     */
    public func log(
        _ level: LogLevel,
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
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
