import libc

/**
    Logger protocol. Custom loggers must conform
    to this protocol
*/
public protocol LogDriver {
    func log(_ level: Log.Level, message: String)
}

/**
    Logs to the console

    - parameter level: LogLevel enum
    - parameter message: String to log
*/
public class ConsoleLogger: LogDriver {
    /**
        The basic log function of the console.

        - parameter level: the level with which to filter
        - parameter message: the message to log to console
     */
    public func log(_ level: Log.Level, message: String) {
        let date = time(nil)
        print("[\(date)] [\(level)] \(message)")
    }
}
