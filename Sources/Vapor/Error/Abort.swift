import Debugging
//import HTTP

/// Errors conforming to this protocol will always be displayed by
/// Vapor to the end-user (even in production mode where most errors are silenced).
public protocol AbortError: Debuggable {
    /// The HTTP status code this error will return.
    var status: HTTPStatus { get }

    /// The human-readable (and hopefully understandable)
    /// reason for this error.
    var reason: String { get }
}

/// Simple abort error.
/// Note: we recommend creating your own error
/// types that conform to `AbortError` and use this
/// error type minimally.
public struct Abort: AbortError {
    /// See Debuggable.identifier
    public var identifier: String

    /// See AbortError.status
    public var status: HTTPStatus

    /// See AbortError.reason
    public var reason: String

    /// See Traceable.file
    public var file: String

    /// See Traceable.function
    public var function: String

    /// See Traceable.line
    public var line: UInt

    /// See Traceable.column
    public var column: UInt

    /// See Traceable.stackTrace
    public var stackTrace: [String]

    /// Create a new abort error.
    public init(
        _ status: HTTPStatus,
        reason: String? = nil,
        identifier: String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = status.code.description
        self.status = status
        self.reason = reason ?? status.message
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.stackTrace = Abort.makeStackTrace()
    }
}
