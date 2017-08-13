import libc
import Console

/// Logs to the console
public final class ConsoleLogger: LogProtocol {
    public let console: Console

    public var enabled: [LogLevel]

    /// Creates an instance of `ConsoleLogger`
    /// with the desired `Console`.
    public init(console: Console) {
        self.console = console
        enabled = LogLevel.all
    }

    /// The basic log function of the console.
    public func log(
        _ level: LogLevel,
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) throws {
        if enabled.contains(level) {
            try console.output(message, style: level.consoleStyle)
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
