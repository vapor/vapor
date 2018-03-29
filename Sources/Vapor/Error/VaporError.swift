import Debugging
import Foundation
import COperatingSystem

/// Errors that can be thrown while working with Vapor.
public struct VaporError: Debuggable {
    /// See `Debuggable`
    public static let readableName = "Vapor Error"

    /// See `Debuggable`
    public let identifier: String

    /// See `Debuggable`
    public var reason: String

    /// See `Debuggable`
    public var sourceLocation: SourceLocation?

    /// See `Debuggable`
    public var stackTrace: [String]

    /// See `Debuggable`
    public var suggestedFixes: [String]

    /// See `Debuggable`
    public var possibleCauses: [String]

    /// Creates a new `VaporError`.
    public init(
        identifier: String,
        reason: String,
        suggestedFixes: [String] = [],
        possibleCauses: [String] = [],
        source: SourceLocation
    ) {
        self.identifier = identifier
        self.reason = reason
        self.sourceLocation = source
        self.stackTrace = VaporError.makeStackTrace()
        self.suggestedFixes = suggestedFixes
        self.possibleCauses = possibleCauses
    }
}

// MARK: Debug

/// For printing errors that cannot be handled in a better way.
func ERROR(_ message: String, file: StaticString = #file, line: Int = #line) {
    print("[Vapor] \(message) [\(file.description.split(separator: "/").last!):\(line)]")
}

/// For printing debug info.
func DEBUG(_ string: @autoclosure () -> String, file: StaticString = #file, line: Int = #line) {
    #if VERBOSE
    print("[VERBOSE] \(string()) [\(file.description.split(separator: "/").last!):\(line)]")
    #endif
}

