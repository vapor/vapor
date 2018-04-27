/// `Console` based `Logger` implementation.
public final class ConsoleLogger: Logger {
    /// The `Console` powering this `Logger`.
    private let console: Console

    /// Create a new `ConsoleLogger`.
    ///
    /// - parameters:
    ///     - console: `Console` to use for logging messages.
    public init(console: Console) {
        self.console = console
    }

    /// See `Logger`.
    public func log(_ string: String, at level: LogLevel, file: String, function: String, line: UInt, column: UInt) {
        console.output(
            ConsoleText(fragments: [
                ConsoleTextFragment(string: "[ ", style: level.consoleStyle),
                ConsoleTextFragment(string: level.description, style: level.consoleStyle),
                ConsoleTextFragment(string: " ] ", style: level.consoleStyle),
                ConsoleTextFragment(string: string),
                ConsoleTextFragment(string: " (", style: .info),
                ConsoleTextFragment(string: String(file.split(separator: "/").last!), style: .info),
                ConsoleTextFragment(string: ":", style: .info),
                ConsoleTextFragment(string: line.description, style: .info),
                ConsoleTextFragment(string: ")", style: .info),
                ]
            )
        )
    }
}

private extension LogLevel {
    /// Converts `LogLevel` to `ConsoleStyle`.
    var consoleStyle: ConsoleStyle {
        switch self {
        case .custom, .verbose, .debug: return .plain
        case .error, .fatal: return .error
        case .info: return .info
        case .warning: return .warning
        }
    }
}
