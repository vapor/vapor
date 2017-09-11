import Debugging

public struct FileError: Debuggable, Traceable, Error {
    /// Kinds of File errors
    enum Kind {
        case invalidDescriptor
        case readError(Int32, path: String)
    }

    /// This error's kind
    internal let kind: Kind

    /// See Debuggable.Reason
    public var reason: String {
        switch kind {
        case .invalidDescriptor:
            return "Invalid file descriptor"
        case .readError(_, let path):
            return "An error occurred while reading \(path)"
        }
    }

    /// See Identifiable.identifier
    public var identifier: String {
        switch kind {
        case .invalidDescriptor:
            return "invalidDescriptor"
        case .readError(let e, _):
            return "readError (\(e))"
        }
    }


    /// See Traceable.file
    public let file: String

    /// See Traceable.function
    public let function: String

    /// See Traceable.line
    public let line: UInt

    /// See Traceable.coumn
    public let column: UInt

    /// See Traceable.stackTrace
    public let stackTrace: [String]

    /// Create a new FileError
    internal init(_ kind: Kind, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) {
        self.kind = kind
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.stackTrace = FileError.makeStackTrace()
    }
}
