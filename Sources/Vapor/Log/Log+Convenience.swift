extension Log {
    /**
     Logs verbose messages if .Verbose is enabled
     
     - parameter message: String to log
     - parameter path: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    //public func verbose(_ message: String) {
    public func verbose(_ message: String, _
        path: String = #file, _ function: String = #function, line: Int = #line) {
        log(.verbose, message: message, path: path, function: function, line: line)
    }
    
    /**
     Logs debug messages if .Debug is enabled
     
     - parameter message: String to log
     - parameter path: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func debug(_ message: String, _
        path: String = #file, _ function: String = #function, line: Int = #line) {
        log(.debug, message: message, path: path, function: function, line: line)
    }
    
    /**
     Logs info messages if .Info is enabled
     
     - parameter message: String to log
     - parameter path: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func info(_ message: String, _
        path: String = #file, _ function: String = #function, line: Int = #line) {
        log(.info, message: message, path: path, function: function, line: line)
    }
    
    /**
     Logs warning messages if .Warning is enabled
     
     - parameter message: String to log
     - parameter path: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func warning(_ message: String, _
        path: String = #file, _ function: String = #function, line: Int = #line) {
        log(.warning, message: message, path: path, function: function, line: line)
    }
    
    /**
     Logs error messages if .Error is enabled
     
     - parameter message: String to log
     - parameter path: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func error(_ message: String, _
        path: String = #file, _ function: String = #function, line: Int = #line) {
        log(.error, message: message, path: path, function: function, line: line)
    }
    
    /**
     Logs fatal messages if .Fatal is enabled
     
     - parameter message: String to log
     - parameter path: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     */
    public func fatal(_ message: String, _
        path: String = #file, _ function: String = #function, line: Int = #line) {
        log(.fatal, message: message, path: path, function: function, line: line)
    }
    
    /**
     Logs custom messages if .Always is enabled.
     
     - parameter message: String to log
     - parameter path: String where logging happens, is automatically set on default
     - parameter function: String where logging happens, is automatically set on default
     - parameter line: String where logging happens, is automatically set on default
     - parameter label: String of a custom logging level
     */
    public func custom(_ message: String, _
        path: String = #file, _ function: String = #function, line: Int = #line, label: String) {
        log(.custom(label), message: message, path: path, function: function, line: line)
    }
}
