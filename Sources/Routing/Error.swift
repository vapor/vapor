import Debugging

/// Errors that can be thrown while working with TCP sockets.
public struct RoutingError: Traceable, Debuggable, Swift.Error, Encodable {
    public static let readableName = "Routing Error"
    public var identifier: String
    public var reason: String
    public var file: String
    public var function: String
    public var line: UInt
    public var column: UInt
    public var stackTrace: [String]

    /// Create a new TCP error.
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
        self.stackTrace = RoutingError.makeStackTrace()
    }
}



