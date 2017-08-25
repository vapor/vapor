import Debugging

/// A WebSocket error, when creating or using a WebSocket
public struct Error : Swift.Error, Debuggable, Traceable {
    /// A description of the problem
    public var reason: String {
        switch problem {
        case .notUpgraded:
            return "The HTTP connection was not upgraded to WebSocket"
        case .invalidMask:
            return "Masks must be 4 bytes, no more, no less"
        case .invalidFrame:
            return "The frame was invalid, likely because the incoming buffer was corrupt or incomplete."
        case .invalidFrameParameters:
            return "WebSocket frames that aren't final must be binary or a continuation of binary"
        case .invalidBufferSize:
            return "The buffer provided was empty"
        case .invalidRequest:
            return "The websocket upgrade request is not valid"
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
    enum Problem : String {
        /// The HTTP connection was not upgraded to WebSocket
        case notUpgraded
        
        /// The buffer size provided for parsing/serializing was empty
        case invalidBufferSize
        
        /// The frame was invalidly formatted
        case invalidFrame
        
        /// The mask was not 4 bytes
        case invalidMask
        
        /// Only binary/continuation frames don't need to be final
        case invalidFrameParameters

        /// The upgrade request was not formatted properly
        case invalidRequest
    }
}
