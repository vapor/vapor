import Debugging

/// Errors that can be thrown while working with JWT
public struct JWTError: Debuggable, Error {
    /// See Debuggable.readableName
    public static var readableName = "JWT Error"

    /// See Debuggable.reason
    public var reason: String

    /// See Debuggable.identifier
    public var identifier: String

    /// Create a new JWT error
    public init(identifier: String, reason: String) {
        self.identifier = identifier
        self.reason = reason
    }
}
