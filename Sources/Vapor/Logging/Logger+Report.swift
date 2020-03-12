extension Logger {
    /// Reports an `Error` to this `Logger`.
    ///
    /// - parameters:
    ///     - error: `Error` to log.
    ///     - request: Optional `Request` associated with this error.
    public func report(
        error: Error,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        let source: ErrorSource?
        let reason: String
        switch error {
        case let debuggable as DebuggableError:
            if self.logLevel <= .debug {
                reason = debuggable.debuggableHelp(format: .short)
            } else {
                reason = debuggable.debuggableHelp(format: .long)
            }
            source = debuggable.source
        case let localized as LocalizedError:
            reason = localized.localizedDescription
            source = nil
        case let convertible as CustomStringConvertible:
            reason = convertible.description
            source = nil
        default:
            reason = "\(error)"
            source = nil
        }
        self.log(
            level: .error,
            .init(stringLiteral: reason),
            file: source?.file ?? file,
            function: source?.function ?? function,
            line: numericCast(source?.line ?? line)
        )
    }
}
