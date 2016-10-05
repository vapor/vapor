extension LogProtocol {
    /**
     Logs verbose messages if .Verbose is enabled
     
     - parameter message: String to log
     - parameter file: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func verbose(_ message: String,
        file: String = #file, function: String = #function, line: Int = #line) {
        log(.verbose, message: message, file: file, function: function, line: line)
    }
    
    /**
     Logs debug messages if .Debug is enabled
     
     - parameter message: String to log
     - parameter file: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func debug(_ message: String,
        file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message: message, file: file, function: function, line: line)
    }
    
    /**
     Logs info messages if .Info is enabled
     
     - parameter message: String to log
     - parameter file: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func info(_ message: String,
        file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: message, file: file, function: function, line: line)
    }
    
    /**
     Logs warning messages if .Warning is enabled
     
     - parameter message: String to log
     - parameter file: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func warning(_ message: String,
        file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: message, file: file, function: function, line: line)
    }
    
    /**
     Logs error messages if .Error is enabled
     
     - parameter message: String to log
     - parameter file: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func error(_ message: String,
        file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message: message, file: file, function: function, line: line)
    }
    
    /**
     Logs fatal messages if .Fatal is enabled
     
     - parameter message: String to log
     - parameter file: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func fatal(_ message: String,
        file: String = #file, function: String = #function, line: Int = #line) {
        log(.fatal, message: message, file: file, function: function, line: line)
    }
    
    /**
     Logs custom messages if .Always is enabled.
     
     - parameter message: String to log
     - parameter file: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     - parameter label: String of a custom logging level
     */
    public func custom(_ message: String,
        file: String = #file, function: String = #function, line: Int = #line, label: String) {
        log(.custom(label), message: message, file: file, function: function, line: line)
    }
}
