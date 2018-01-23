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
        console.output("[ ", style: level.style, newLine: false)
        console.output(level.description, style: level.style, newLine: false)
        console.output(" ] ", style: level.style, newLine: false)
        console.print(string, newLine: false)
        let file = String(file.split(separator: "/").last!)
        console.output(" (", style: .info, newLine: false)
        console.output(file, style: .info, newLine: false)
        console.output(":", style: .info, newLine: false)
        console.output(line.description, style: .info, newLine: false)
        console.output(")", style: .info, newLine: false)
        console.print()
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
