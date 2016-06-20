extension Log {
    /**
     Logs verbose messages if .Verbose is enabled

     - parameter message: String to log
     */
    public func verbose(_ message: String) {
        log(.verbose, message: message)
    }

    /**
     Logs debug messages if .Debug is enabled

     - parameter message: String to log
     */
    public func debug(_ message: String) {
        log(.debug, message: message)
    }

    /**
     Logs info messages if .Info is enabled

     - parameter message: String to log
     */
    public func info(_ message: String) {
        log(.info, message: message)
    }

    /**
     Logs warning messages if .Warning is enabled

     - parameter message: String to log
     */
    public func warning(_ message: String) {
        log(.warning, message: message)
    }

    /**
     Logs error messages if .Error is enabled

     - parameter message: String to log
     */
    public func error(_ message: String) {
        log(.error, message: message)
    }

    /**
     Logs fatal messages if .Fatal is enabled

     - parameter message: String to log
     */
    public func fatal(_ message: String) {
        log(.fatal, message: message)
    }

    /**
     Logs custom messages if .Always is enabled.

     - parameter message: String to log
     */
    public func custom(_ message: String, label: String) {
        log(.custom(label), message: message)
    }
}
