import Debugging

/// Errors thrown while encoding/decoding form-urlencoded data.
public struct FormURLError: Error, Debuggable {
    /// See Debuggable.identifier
    public var identifier: String

    /// See Debuggable.reason
    public let reason: String

    /// Creates a new form url error
    internal init(identifier: String, reason: String) {
        self.identifier = identifier
        self.reason = reason
    }
}
