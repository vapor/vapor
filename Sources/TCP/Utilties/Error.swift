import Debugging
import libc

/// Errors that can be thrown while working with TCP sockets.
public struct Error: Traceable, Debuggable, Swift.Error, Encodable {
    public static let readableName = "TCP Error"
    public let identifier: String
    public var reason: String
    public var file: String
    public var function: String
    public var line: UInt
    public var column: UInt
    public var stackTrace: [String]

    /// Create a new TCP error.
    public init(
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
        self.stackTrace = Error.makeStackTrace()
    }

    /// Create a new TCP error from a POSIX errno.
    public static func posix(
        _ errno: Int32,
        identifier: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) -> Error {
        let message = libc.strerror(errno)
        let string = String(cString: message!, encoding: .utf8) ?? "unknown"
        return Error(
            identifier: identifier,
            reason: string,
            file: file,
            function: function,
            line: line,
            column: column
        )
    }
}


