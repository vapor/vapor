import Debugging

/// An error converting types.
public struct CoreError: Debuggable, Error {
    /// See Debuggable.reason
    public var reason: String

    /// See Debuggable.identifier
    public var identifier: String

    /// Creates a new core error.
    init(identifier: String, reason: String) {
        self.reason = reason
        self.identifier = identifier
    }
}

