import libc

/**
    Logs to the console

    - parameter level: LogLevel enum
    - parameter message: String to log
*/
public class ConsoleLogger: LogDriver {
    let console: Console

    /**
        Creates an instance of `ConsoleLogger`
        with the desired `Console`.
    */
    public init(console: Console) {
        self.console = console
    }

    /**
        The basic log function of the console.

        - parameter level: the level with which to filter
        - parameter message: the message to log to console
     */
    public func log(_ level: Log.Level, message: String) {
        console.output(message, style: level.consoleStyle)
    }
}

extension Log.Level {
    var consoleStyle: Console.Style {
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
