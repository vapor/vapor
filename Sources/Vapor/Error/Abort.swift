/// Default implementation of `AbortError`. You can use this as a convenient method for throwing
/// `AbortError`s without having to conform your own error-type to `AbortError`.
///
///     throw Abort(.badRequest, reason: "Something's not quite right...")
///
public struct Abort: AbortError {
    /// Creates a redirecting `Abort` error.
    ///
    ///     throw Abort.redirect(to: "https://vapor.codes")"
    ///
    /// Set type to '.permanently' to allow caching to automatically redirect from browsers.
    /// Defaulting to non-permanent to prevent unexpected caching.
    public static func redirect(to location: String, type: RedirectType = .normal) -> Abort {
        var headers: HTTPHeaders = [:]
        headers.replaceOrAdd(name: .location, value: location)
        return .init(type.status, headers: headers)
    }

    /// See `Debuggable`
    public var identifier: String

    /// See `AbortError`
    public var status: HTTPResponseStatus

    /// See `AbortError`.
    public var headers: HTTPHeaders

    /// See `AbortError`
    public var reason: String

    /// See `Debuggable`
    public var sourceLocation: SourceLocation?

    /// See `Debuggable`
    public var stackTrace: [String]
    
    /// See `Debuggable`
    public var suggestedFixes: [String]

    /// Create a new `Abort`, capturing current source location info.
    public init(
        _ status: HTTPResponseStatus,
        headers: HTTPHeaders = [:],
        reason: String? = nil,
        identifier: String? = nil,
        suggestedFixes: [String] = [],
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = status.code.description
        self.headers = headers
        self.status = status
        self.reason = reason ?? status.reasonPhrase
        self.suggestedFixes = suggestedFixes
        self.sourceLocation = SourceLocation(file: file, function: function, line: line, column: column, range: nil)
        self.stackTrace = Abort.makeStackTrace()
    }
}
