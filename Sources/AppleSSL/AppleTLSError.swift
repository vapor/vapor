import Foundation
import Debugging
import Security

/// An SSL Error related to Apple's Security libraries
public struct AppleTLSError: Traceable, Debuggable, Helpable, Swift.Error, Encodable {
    public static let readableName = "Apple TLS Error"
    public let identifier: String
    public var reason: String
    public var file: String
    public var function: String
    public var line: UInt
    public var column: UInt
    public var stackTrace: [String]
    public var possibleCauses: [String]
    public var suggestedFixes: [String]
    
    /// Creates a new Apple TLS error
    public init(
        identifier: String,
        reason: String,
        possibleCauses: [String] = [],
        suggestedFixes: [String] = [],
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
        self.stackTrace = AppleTLSError.makeStackTrace()
        self.possibleCauses = possibleCauses
        self.suggestedFixes = suggestedFixes
    }


    public static func secError(
        _ status: OSStatus,
        possibleCauses: [String] = [],
        suggestedFixes: [String] = [],
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) -> AppleTLSError {
        let reason = SecCopyErrorMessageString(status, nil).flatMap { String($0) } ?? "An error occurred when setting up the TLS connection"
        return AppleTLSError(
            identifier: status.description,
            reason: reason,
            possibleCauses: possibleCauses,
            suggestedFixes: suggestedFixes,
            file: file,
            function: function,
            line: line,
            column: column
        )
    }
}
