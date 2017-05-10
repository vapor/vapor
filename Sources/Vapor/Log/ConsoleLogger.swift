import libc
import Console

/// Logs to the console
public final class ConsoleLogger: LogProtocol {
    let console: ConsoleProtocol

    public var enabled: [LogLevel]

    /// Creates an instance of `ConsoleLogger`
    /// with the desired `Console`.
    public init(_ console: ConsoleProtocol) {
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
    ) {
        if enabled.contains(level) {
            console.output(message, style: level.consoleStyle)
        }
    }
}

extension ConsoleLogger: ConfigInitializable {
    public convenience init(config: Config) throws {
        let console = try config.resolveConsole()
        self.init(console)
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
