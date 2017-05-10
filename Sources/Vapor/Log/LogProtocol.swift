import Configs
import Console

/// Logger protocol. Custom loggers must conform
/// to this protocol
public protocol LogProtocol: class {
    /// Enabled log levels. Only levels in this
    /// array should be logged.
    var enabled: [LogLevel] { get set }

    /// Log the given message at the passed filter level.
    /// file, function and line of the logging call
    /// are automatically injected in the convenience function.
    func log(_ level: LogLevel, message: String, file: String, function: String, line: Int)
}
