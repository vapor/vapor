/**
    Log messages to the console using
    the static methods on this class.
*/
public class Log {

    /**
        LogLevel enumeration
    */
    public enum Level: Equatable, CustomStringConvertible {
        case verbose, debug, info, warning, error, fatal, custom(String)

        /*
         Returns all standard log levels (i.e. except Custom)

         returns - array of Log.Level
         */
        public static var all: [Log.Level] {
            return [.verbose, .debug, .info, .warning, .error, .fatal]
        }

        public var description: String {
            switch self {
            case verbose: return "VERBOSE"
            case debug: return "DEBUG"
            case info: return "INFO"
            case warning: return "WARNING"
            case error: return "ERROR"
            case fatal: return "FATAL"
            case custom(let string): return "\(string.uppercased())"
            }
        }
    }

    /**
        LogDriver. Default is the console logger.
        This can be overriden with a custom logger.
     */
    public static var driver: LogDriver = ConsoleLogger()

    /**
        Enabled log levels. Default is to log all levels. This
        can be overridden.
     */
    public static var enabledLevels: [Level] = Log.Level.all

    /**
        Logs verbose messages if .Verbose is enabled

        - parameter message: String to log
     */
    public static func verbose(_ message: String) {
        if Log.enabledLevels.contains(.verbose) {
            driver.log(.verbose, message: message)
        }
    }

    /**
        Logs debug messages if .Debug is enabled

        - parameter message: String to log
     */
    public static func debug(_ message: String) {
        if Log.enabledLevels.contains(.debug) {
            driver.log(.debug, message: message)
        }
    }

    /**
        Logs info messages if .Info is enabled

        - parameter message: String to log
     */
    public static func info(_ message: String) {
        if Log.enabledLevels.contains(.info) {
            driver.log(.info, message: message)
        }
    }

    /**
        Logs warning messages if .Warning is enabled

        - parameter message: String to log
     */
    public static func warning(_ message: String) {
        if Log.enabledLevels.contains(.warning) {
             driver.log(.warning, message: message)
        }
    }

    /**
        Logs error messages if .Error is enabled

        - parameter message: String to log
     */
    public static func error(_ message: String) {
        if Log.enabledLevels.contains(.error) {
            driver.log(.error, message: message)
        }
    }

    /**
        Logs fatal messages if .Fatal is enabled

        - parameter message: String to log
     */
    public static func fatal(_ message: String) {
        if Log.enabledLevels.contains(.fatal) {
            driver.log(.fatal, message: message)
        }
    }

    /**
        Logs custom messages if .Always is enabled.

        - parameter message: String to log
     */
    public static func custom(_ message: String, label: String) {
        driver.log(.custom(label), message: message)
    }
}

public func == (lhs: Log.Level, rhs: Log.Level) -> Bool {
    return lhs.description == rhs.description
}
