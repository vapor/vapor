public protocol Logger {
    /// Logs an encodable at the provided log level
    ///
    /// The encodable can be encoded to the required format
    ///
    /// The log level indicates the type of log and/or severity
    func log(_ string: String, at level: LogLevel, file: String, function: String, line: UInt, column: UInt)
}

extension Logger {
    /// Verbose logs are used to log tiny, usually irrelevant information.
    /// They are helpful when tracing specific lines of code and their results
    ///
    /// Example:
    ///
    ///     let a = 1 + 4
    ///     logger.debug(a)
    ///     let b = 1 - 3
    ///     logger.debug(b)
    ///     let c = (b + a) * 3
    ///     logger.debug(c)
    public func verbose(_ encodable: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.log(encodable, at: .verbose, file: file, function: function, line: line, column: column)
    }
    
    /// Debug logs are used to debug problems
    ///
    /// Example:
    ///
    /// The password hash verification for user XYZ@example.com has failed/succeeded
    public func debug(_ encodable: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.log(encodable, at: .debug, file: file, function: function, line: line, column: column)
    }
    
    /// Info logs are used to indicate a specific infrequent event occurring.
    ///
    /// Example:
    ///
    /// The daily database sanity check will start executing now.
    public func info(_ encodable: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.log(encodable, at: .info, file: file, function: function, line: line, column: column)
    }
    
    /// Warnings are used to indicate something should be fixed but may not have to be solved yet
    ///
    /// Example:
    ///
    /// Loading a template from the filesystem failed, resulting in a 404
    public func warning(_ encodable: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.log(encodable, at: .warning, file: file, function: function, line: line, column: column)
    }
    
    /// Error, indicates something went wrong and a part of the execution was failed.
    ///
    /// Example:
    ///
    /// When a database query fails, socket drops, etc..
    public func error(_ encodable: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.log(encodable, at: .error, file: file, function: function, line: line, column: column)
    }
    
    /// Fatal errors/crashes, execution should/must be cancelled
    ///
    /// Example:
    ///
    /// On initialization failure
    public func fatal(_ encodable: String, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.log(encodable, at: .fatal, file: file, function: function, line: line, column: column)
    }
}
