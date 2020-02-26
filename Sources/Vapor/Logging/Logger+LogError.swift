extension Logger {
    /// Reports an `Error` to this `Logger`.
    ///
    /// - parameters:
    ///     - error: `Error` to log.
    ///     - request: Optional `Request` associated with this error.
    public func report(
        error: Error,
        request: Request? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
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
        let message: Logger.Message
        if let request = request {
            message = "\(request.method) \(request.url.path): \(reason)"
        } else {
            message = .init(stringLiteral: reason)
        }
        self.log(
            level: .error,
            message,
            file: file,
            function: function,
            line: numericCast(line)
        )
    }
}
