import Debugging

/// Errors that can be thrown while working with validation
public struct BasicValidationError: ValidationError {
    /// See Debuggable.reason
    public var reason: String {
        let path = keyPath.joined(separator: ".")
        return "`\(path)` \(message)"
    }

    /// The validation failure
    public var message: String

    /// Key path the validation error happened at
    public var keyPath: [String]

    /// Create a new JWT error
    public init(_ message: String) {
        self.message = message
        self.keyPath = []
    }
}

/// A validation error that supports dynamic
/// key paths.
public protocol ValidationError: Debuggable, Error {
    /// See Debuggable.reason
    var reason: String { get }

    /// Key path the validation error happened at
    var keyPath: [String] { get set }
}

extension ValidationError {
    /// See Debuggable.identifier
    public var identifier: String {
        return "validationFailed"
    }
}
