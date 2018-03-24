/// Default implementation of `AbortError`. You can use this as a convenient method for throwing
/// `AbortError`s without having to conform your own error-type to `AbortError`.
///
///     throw Abort(.badRequest, reason: "Something's not quite right...")
///
public struct Abort: AbortError {
    /// See `Debuggable.identifier`
    public var identifier: String

    /// See `AbortError.status`
    public var status: HTTPResponseStatus

    /// See `AbortError.reason`
    public var reason: String

    /// See `Debuggable.sourceLocation`
    public var sourceLocation: SourceLocation?

    /// See `Debuggable.stackTrace`
    public var stackTrace: [String]

    /// Create a new `Abort`, capturing current source location info.
    public init(
        _ status: HTTPResponseStatus,
        reason: String? = nil,
        identifier: String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = status.code.description
        self.status = status
        self.reason = reason ?? status.reasonPhrase
        self.sourceLocation = SourceLocation(file: file, function: function, line: line, column: column, range: nil)
        self.stackTrace = Abort.makeStackTrace()
    }
}
