extension Logger {
    /// Reports an `Error` to this `Logger`, first checking if it is `Debuggable`
    /// for improved debug info.
    ///
    /// - parameters:
    ///     - error: `Error` to log.
    ///     - verbose: If `true`, extra lines of debug information will be printed containing
    ///                things like suggested fixes, possible causes, or other info.
    ///                Defaults to `true`.
    public func report(
        error e: Error,
        path: String? = nil,
        verbose: Bool = true,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        switch e {
        case let debuggable as Debuggable:
            
            let pathString: String
            if let path = path {
                pathString = " \(path)"
            } else {
                pathString = ""
            }
            
            let errorString = "\(debuggable.fullIdentifier):\(pathString) \(debuggable.reason)"
            if let source = debuggable.sourceLocation {
                error(errorString, file: source.file.lastPart, function: source.function, line: source.line, column: source.column)
            } else {
                error(errorString, file: file.lastPart, function: function, line: line, column: column)
            }
            if verbose, debuggable.suggestedFixes.count > 0 {
                let str = "Suggested fixes for \(debuggable.fullIdentifier): " + debuggable.suggestedFixes.joined(separator: " ")
                debug(str, file: file.lastPart, function: function, line: line, column: column)
            }
            if verbose, debuggable.possibleCauses.count > 0 {
                let str = "Possible causes for \(debuggable.fullIdentifier): " + debuggable.possibleCauses.joined(separator: " ")
                debug(str, file: file.lastPart, function: function, line: line, column: column)
            }
        default:
            let reason: String
            switch e {
            case let localized as LocalizedError: reason = localized.localizedDescription
            case let convertible as CustomStringConvertible: reason = convertible.description
            default: reason = "\(e)"
            }
            error(reason, file: file.lastPart, function: function, line: line, column: column)
            if verbose {
                let str = "Conform `\(type(of: e))` to `Debuggable` for better debug info."
                debug(str, file: file.lastPart, function: function, line: line, column: column)
            }
        }
    }
}

private extension String {
    var lastPart: String {
        return split(separator: "/").last.map(String.init) ?? self
    }
}
