import HTTP

/// Errors conforming to this protocol will always be displayed by
/// Vapor to the end-user (even in production mode where most errors are silenced).
public protocol AbortError: Swift.Error {
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
    /// See AbortError.status
    public var status: HTTPStatus

    /// See AbortError.reason
    public var reason: String

    /// Create a new abort error.
    public init(_ status: HTTPStatus, reason: String? = nil) {
        self.status = status
        self.reason = status.message
    }
}
