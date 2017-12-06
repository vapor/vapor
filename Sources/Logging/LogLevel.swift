
/// All log levels
public enum LogLevel: ExpressibleByStringLiteral, CustomStringConvertible {
    /// Verbose logs are used to log tiny, usually irrelevant information.
    /// They are helpful when tracing specific lines of code and their results
    ///
    /// Example:
    ///
    ///     let a = 1 + 4
    ///     logger.debug(a)
    ///     let b = 1 - 3
    ///     logger.debug(b)
    ///     let c = (b + a) * 3
    ///     logger.debug(c)
    case verbose

    /// Debug logs are used to debug problems
    ///
    /// Example:
    ///
    /// The password hash verification for user XYZ@example.com has failed/succeeded
    case debug

    /// Info logs are used to indicate a specific infrequent event occurring.
    ///
    /// Example:
    ///
    /// The daily database sanity check will start executing now.
    case info

    /// Warnings are used to indicate something should be fixed but may not have to be solved yet
    ///
    /// Example:
    ///
    /// Loading a template from the filesystem failed, resulting in a 404
    case warning

    /// Error, indicates something went wrong and a part of the execution was failed.
    ///
    /// Example:
    ///
    /// When a database query fails, socket drops, etc..
    case error

    /// Fatal errors/crashes, execution should/must be cancelled
    ///
    /// Example:
    ///
    /// On initialization failure
    case fatal

    /// A custom log level, if the default ones aren't enough
    case custom(String)

    /// Creates a custom log level
    public init(stringLiteral value: String) {
        self = .custom(value)
    }

    /// See CustomStringConvertible.description
    public var description: String {
        switch self {
        case .custom(let s): return s.uppercased()
        case .debug: return "DEBUG"
        case .error: return "ERROR"
        case .fatal: return "FATAL"
        case .info: return "INFO"
        case .verbose: return "VERBOSE"
        case .warning: return "WARNING"
        }
    }
}

