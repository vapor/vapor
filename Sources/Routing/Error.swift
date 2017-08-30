import Debugging

/// Errors that can be thrown while working with TCP sockets.
public struct Error: Traceable, Debuggable, Swift.Error {
    enum Kind {
        case insufficientParameters
        case invalidParameterType(actual: Any.Type, expected: Any.Type)
    }

    public static let readableName = "Routing Error"

    let kind: Kind

    public var identifier: String {
        switch kind {
        case .insufficientParameters:
            return "insufficientParameters"
        case .invalidParameterType:
            return "invalidParameterType"
        }
    }

    public var reason: String {
        switch kind {
        case .invalidParameterType:
            return "Invalid parameter type"
        case .insufficientParameters:
            return "Insufficient parameters."
        }
    }

    public var file: String
    public var function: String
    public var line: UInt
    public var column: UInt
    public var stackTrace: [String]

    /// Create a new TCP error.
    init(
        _ kind: Kind,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.kind = kind
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.stackTrace = Error.makeStackTrace()
    }
}



