import Console
import Logging

/// Logs messages to a console
public final class ConsoleLogger: Logger {
    /// The console
    public let console: Console

    /// Create a new console logger
    public init(console: Console) {
        self.console = console
    }

    /// See ConsoleLogger.log
    public func log(_ string: String, at level: LogLevel, file: String, function: String, line: UInt, column: UInt) {
        console.output(
            ConsoleText(fragments: [
                ConsoleTextFragment(string: "[ ", style: level.style),
                ConsoleTextFragment(string: level.description, style: level.style),
                ConsoleTextFragment(string: " ] ", style: level.style),
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

extension LogLevel {
    /// Converts log level to console style
    fileprivate var style: ConsoleStyle {
        switch self {
        case .custom, .verbose, .debug: return .plain
        case .error, .fatal: return .error
        case .info: return .info
        case .warning: return .warning
        }
    }
}
