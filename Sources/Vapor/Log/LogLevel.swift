/**
    Different levels of priority 
    messages can be logged at.
*/
public enum LogLevel: Equatable, CustomStringConvertible {
    case verbose, debug, info, warning, error, fatal, custom(String)

    /*
        Returns all standard log levels (i.e. except Custom)
    */
    public static var all: [LogLevel] {
        return [.verbose, .debug, .info, .warning, .error, .fatal]
    }

    public var description: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .fatal: return "FATAL"
        case .custom(let string): return "\(string.uppercased())"
        }
    }
}

public func == (lhs: LogLevel, rhs: LogLevel) -> Bool {
    return lhs.description == rhs.description
}
