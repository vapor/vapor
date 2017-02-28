import Debugging
import HTTP

/// Represents errors that can be thrown in any Vapor closure.
/// Then, these errors can be caught in `Middleware` to give a
/// desired response.
public protocol AbortError: Swift.Error {
    /// The HTTP status code to return.
    var status: Status { get }

    /// `Optional` metadata.
    var metadata: Node? { get }
}
