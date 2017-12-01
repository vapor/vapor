import Debugging
import Vapor

/// Errors that can be thrown while working with Authentication.
public struct AuthenticationError: Traceable, Debuggable, Error {
    /// See Debuggable.readableName
    public static let readableName = "Authentication Error"

    /// See Debuggable.reason
    public let identifier: String

    /// See Debuggable.reason
    public var reason: String

    /// See Traceable.
    public var file: String

    /// See Traceable.function
    public var function: String

    /// See Traceable.line
    public var line: UInt

    /// See Traceable.column
    public var column: UInt

    /// See Traceable.stackTrace
    public var stackTrace: [String]

    /// Create a new authentication error.
    init(
        identifier: String,
        reason: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = identifier
        self.reason = reason
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.stackTrace = AuthenticationError.makeStackTrace()
    }
}

extension AuthenticationError: AbortError {
    /// See AbortError.status
    public var status: HTTPStatus {
        return .unauthorized
    }
}
