/**
    Logger protocol. Custom loggers must conform
    to this protocol
*/
public protocol Log: class {
    /**
        Enabled log levels. Only levels in this
        array should be logged.
    */
    var enabled: [LogLevel] { get set }

    /**
        Log the given message at the passed filter level.
    */
    func log(_ level: LogLevel, message: String)
}
