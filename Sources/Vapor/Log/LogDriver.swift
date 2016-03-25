import libc

/**
    Logger protocol. Custom loggers must conform 
    to this protocol
*/
public protocol LogDriver {
    func log(level: Log.Level, message: String)
}

/**
    Logs to the console

    - parameter level: LogLevel enum
    - parameter message: String to log
*/
public class ConsoleLogger: LogDriver {
    
    public func log(level: Log.Level, message: String) {
        let date = time(nil)
        print("[\(date)] [\(level)] \(message)")
    }
}
