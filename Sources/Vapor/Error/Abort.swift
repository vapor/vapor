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
    public var stackTrace: [String]?

    /// See `Debuggable`
    public var possibleCauses: [String]

    /// See `Debuggable`
    public var suggestedFixes: [String]

    /// See `Debuggable`
    public var documentationLinks: [String]

    /// See `Debuggable`
    public var stackOverflowQuestions: [String]

    /// See `Debuggable`
    public var gitHubIssues: [String]

    /// Create a new `Abort`, capturing current source location info.
    public init(
        _ status: HTTPResponseStatus,
        headers: HTTPHeaders = [:],
        reason: String? = nil,
        identifier: String? = nil,
        possibleCauses: [String] = [],
        suggestedFixes: [String] = [],
        documentationLinks: [String] = [],
        stackOverflowQuestions: [String] = [],
        gitHubIssues: [String] = [],
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = status.code.description
        self.headers = headers
        self.status = status
        self.reason = reason ?? status.reasonPhrase
        self.possibleCauses = possibleCauses
        self.suggestedFixes = suggestedFixes
        self.documentationLinks = documentationLinks
        self.stackOverflowQuestions = stackOverflowQuestions
        self.gitHubIssues = gitHubIssues
        self.sourceLocation = SourceLocation(file: file, function: function, line: line, column: column, range: nil)
        self.stackTrace = Abort.makeStackTrace()
    }

    /// Create a new `Abort` from an error conforming to `AbortError`,
    /// capturing current source location info.
    public init(
        _ error: AbortError,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.init(
            error.status,
            headers: error.headers,
            reason: error.reason,
            identifier: error.identifier,
            possibleCauses: error.possibleCauses,
            suggestedFixes: error.suggestedFixes,
            documentationLinks: error.documentationLinks,
            stackOverflowQuestions: error.stackOverflowQuestions,
            gitHubIssues: error.gitHubIssues,
            file: file,
            function: function,
            line: line,
            column: column
        )
    }
}
