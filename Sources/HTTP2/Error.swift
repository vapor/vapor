import Debugging

/// A WebSocket error, when creating or using a WebSocket
public struct Error : Swift.Error, Debuggable, Traceable, Encodable {
    /// A description of the problem
    public var reason: String {
        switch problem {
        case .notUpgraded:
            return "The HTTP request was not a valid HTTP2 upgrade request"
        }
    }
    
    /// How we got to this problem
    public var stackTrace: [String]
    
    /// The problem's unique identifier
    public var identifier: String {
        return self.problem.rawValue
    }
    
    /// Creates a new problem
    init(_ problem: Problem,
         file: String = #file,
         function: String = #function,
         line: UInt = #line,
         column: UInt = #column
        ) {
        self.stackTrace = Error.makeStackTrace()
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.problem = problem
    }
    
    /// The file this occurred in
    public let file: String
    
    /// The function this occurred from
    public let function: String
    
    /// The line this occurred at
    public let line: UInt
    
    /// The column this occurred at
    public let column: UInt
    
    /// The problem
    internal let problem: Problem
    
    /// The problem occurring
    enum Problem: String {
        /// The HTTP connection was not upgraded to HTTP2
        case notUpgraded
    }
}

