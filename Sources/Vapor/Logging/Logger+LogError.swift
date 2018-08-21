extension Logger {
    /// Reports an `Error` to this `Logger`, first checking if it is `Debuggable`
    /// for improved debug info.
    ///
    /// - parameters:
    ///     - error: `Error` to log.
    ///     - verbose: If `true`, extra lines of debug information will be printed containing
    ///                things like suggested fixes, possible causes, or other info.
    ///                Defaults to `true`.
    public func report(error e: Error, verbose: Bool = true) {
        switch e {
        case let debuggable as Debuggable:
            let errorString = "\(debuggable.fullIdentifier): \(debuggable.reason)"
            if let source = debuggable.sourceLocation {
                error(errorString, file: source.file, function: source.function, line: source.line, column: source.column)
            } else {
                error(errorString)
            }
            if verbose, debuggable.suggestedFixes.count > 0 {
                debug("Suggested fixes for \(debuggable.fullIdentifier): " + debuggable.suggestedFixes.joined(separator: " "))
            }
            if verbose, debuggable.possibleCauses.count > 0 {
                debug("Possible causes for \(debuggable.fullIdentifier): " + debuggable.possibleCauses.joined(separator: " "))
            }
        default:
            let reason: String
            switch e {
            case let localized as LocalizedError: reason = localized.localizedDescription
            case let convertible as CustomStringConvertible: reason = convertible.description
            default: reason = "\(e)"
            }
            error(reason)
            if verbose {
                debug("Conform `\(type(of: e))` to `Debuggable` for better debug info.")
            }
        }
    }
}
