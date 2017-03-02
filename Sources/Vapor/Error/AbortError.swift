import Debugging
import HTTP

/// Represents errors that can be thrown in any Vapor closure.
/// Then, these errors can be caught in `Middleware` to give a
/// desired response.
public protocol AbortError: Swift.Error {
    /// The HTTP status code to return.
    var status: Status { get }

    // The reason this error was thrown.
    /// - Warning: This string will be
    /// displayed in production mode.
    var reason: String { get }

    /// `Optional` metadata.
    /// This will not be shown in production mode.
    var metadata: Node? { get }
}

// MARK: Optional

extension AbortError {
    public var metadata: Node? {
        return nil
    }
}

// MARK: Conformances

extension HTTP.Status: AbortError {
    public var status: Status {
        return self
    }

    public var reason: String {
        return self.reasonPhrase
    }
}
