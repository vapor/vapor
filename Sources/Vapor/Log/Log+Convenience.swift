extension LogProtocol {
    /// Logs verbose messages if .Verbose is enabled
    public func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) throws {
        try log(.verbose, message: message, file: file, function: function, line: line)
    }
    
    /// Logs debug messages if .Debug is enabled
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) throws {
        try log(.debug, message: message, file: file, function: function, line: line)
    }
    
    /// Logs info messages if .Info is enabled
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) throws {
        try log(.info, message: message, file: file, function: function, line: line)
    }
    
    /// Logs warning messages if .warning is enabled
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) throws {
        try log(.warning, message: message, file: file, function: function, line: line)
    }
    
    /// Logs error messages if .error is enabled
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) throws {
        try log(.error, message: message, file: file, function: function, line: line)
    }
    
    /// Logs fatal messages if .fatal is enabled
    public func fatal(_ message: String, file: String = #file, function: String = #function, line: Int = #line) throws {
        try log(.fatal, message: message, file: file, function: function, line: line)
    }
    
    /// Logs custom messages if .always is enabled.
    public func custom(_ message: String, file: String = #file, function: String = #function, line: Int = #line, label: String) throws {
        try log(.custom(label), message: message, file: file, function: function, line: line)
    }
}
