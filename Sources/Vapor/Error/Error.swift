import Debugging

/// Errors that can be thrown while working with Vapor.
public struct VaporError: Debuggable {
    /// See `Debuggable`.
    public static let readableName = "Vapor Error"

    /// See `Debuggable`.
    public let identifier: String

    /// See `Debuggable`.
    public var reason: String

    /// See `Debuggable`.
    public var sourceLocation: SourceLocation?

    /// See `Debuggable`.
    public var stackTrace: [String]

    /// See `Debuggable`.
    public var suggestedFixes: [String]

    /// See `Debuggable`.
    public var possibleCauses: [String]

    /// Creates a new `VaporError`.
    public init(
        identifier: String,
        reason: String,
        suggestedFixes: [String] = [],
        possibleCauses: [String] = [],
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identifier = identifier
        self.reason = reason
        self.sourceLocation = SourceLocation(file: file, function: function, line: line, column: column, range: nil)
        self.stackTrace = VaporError.makeStackTrace()
        self.suggestedFixes = suggestedFixes
        self.possibleCauses = possibleCauses
    }
}

// MARK: Internal

/// For printing debug info.
func DEBUG(_ string: @autoclosure () -> String, file: StaticString = #file, line: Int = #line) {
    #if VERBOSE
    print("[Vapor] [VERBOSE] \(string()) [\(file.description.split(separator: "/").last!):\(line)]")
    #endif
}

/// For printing error info.
func ERROR(_ message: String, file: StaticString = #file, line: Int = #line) {
    print("[Vapor] [ERROR] \(message) [\(file.description.split(separator: "/").last!):\(line)]")
}

/// For printing warning info.
func WARNING(_ message: String, file: StaticString = #file, line: Int = #line) {
    print("[Vapor] [WARNING] \(message) [\(file.description.split(separator: "/").last!):\(line)]")
}

/// Body will only be included in non-release builds.
internal func debugOnly(_ body: () -> Void) {
    assert({ body(); return true }())
}
