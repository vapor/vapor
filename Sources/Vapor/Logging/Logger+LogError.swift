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
        error: Error,
        verbose: Bool = true,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
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
            file: file,
            function: function,
            line: line
        )
    }
}
