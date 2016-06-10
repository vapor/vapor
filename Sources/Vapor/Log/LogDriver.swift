/**
    Logger protocol. Custom loggers must conform
    to this protocol
*/
public protocol LogDriver {
    /**
        Log the given message at the passed filter level
     */
    func log(_ level: Log.Level, message: String)
}
