import Debugging
import Foundation
import COperatingSystem

/// Errors that can be thrown while working with Leaf.
public struct LeafError: Traceable, Debuggable, Swift.Error, Encodable {
    public static let readableName = "Leaf Error"
    public let identifier: String
    public var reason: String
    public var file: String
    public var function: String
    public var line: UInt
    public var column: UInt
    public var stackTrace: [String]
    
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
        self.stackTrace = LeafError.makeStackTrace()
    }
}

