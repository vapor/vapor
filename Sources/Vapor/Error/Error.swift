import Debugging
import Foundation
import COperatingSystem

/// Errors that can be thrown while working with Vapor.
public struct VaporError: Debuggable {
    public static let readableName = "Vapor Error"
    public let identifier: String
    public var reason: String
    public var sourceLocation: SourceLocation?
    public var stackTrace: [String]
    public var suggestedFixes: [String]
    public var possibleCauses: [String]

    init(
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
/// For printing debug info.
func DEBUG(_ string: @autoclosure () -> String, file: StaticString = #file, line: Int = #line) {
    #if VERBOSE
    print("[Vapor] [VERBOSE] \(string()) [\(file.description.split(separator: "/").last!):\(line)]")
    #endif
}

func ERROR(_ message: String, file: StaticString = #file, line: Int = #line) {
    print("[Vapor] [ERROR] \(message) [\(file.description.split(separator: "/").last!):\(line)]")
}

func WARNING(_ message: String, file: StaticString = #file, line: Int = #line) {
    print("[Vapor] [WARNING] \(message) [\(file.description.split(separator: "/").last!):\(line)]")
}

internal func debugOnly(_ body: () -> Void) {
    assert({ body(); return true }())
}
