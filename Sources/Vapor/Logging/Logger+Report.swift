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
        if let abort = error as? AbortError {
            source = abort.source
        } else {
            source = nil
        }

        let reason: String
        switch error {
        case let localized as LocalizedError:
            reason = localized.localizedDescription
        case let convertible as CustomStringConvertible:
            reason = convertible.description
        default:
            reason = "\(error)"
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
