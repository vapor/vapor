import Debugging

/// A WebSocket error, when creating or using a WebSocket
public struct WebSocketError : Swift.Error, Debuggable, Traceable, Helpable, Encodable {
    public var possibleCauses: [String] {
        switch problem {
        case .invalidURI:
            return [
                "The URI was not a valid WebSocket URI"
            ]
        case .parserError:
            return [
                "The parser had an internal error"
            ]
        case .cannotConnect:
            return [
                "The URI was not open to WebSockets/HTTP"
            ]
        case .notUpgraded:
            return [
                "The remote server must support WebSocket at the provided path, port and hostname",
                "The remote server did not send the correct acceptation key"
            ]
        case .invalidMask:
            return [
                "The mask provided was not 4 bytes long as per standard"
            ]
        case .invalidFrame:
            return [
                "The incoming buffer was corrupt or incomplete."
            ]
        case .invalidFrameParameters:
            return [
                "WebSocket frames that aren't final must be binary or a continuation of binary"
            ]
        case .invalidBufferSize:
            return [
                "The binary buffer provided to writing was empty"
            ]
        case .invalidRequest:
            return [
                "The request is not valid for websocket upgrading"
            ]
        case .invalidSubprotocol:
            return [
                "The requested subprotocols are not valid"
            ]
        }
    }
    
    public var suggestedFixes: [String] {
        switch problem {
        case .invalidURI:
            return [
                "The scheme must be either `ws` or `wss`",
                "The hostname must be set and a valid hostname"
            ]
        case .parserError:
            return [
                "Please file a bug including stack trace and a lot of details, so we can fix this"
            ]
        case .cannotConnect:
            return []
        case .notUpgraded:
            return []
        case .invalidMask:
            return [
                "Generate 4 random bytes using any Random Number Generator for clients",
                "Leave the mask empty (`nil`) for servers"
            ]
        case .invalidFrame:
            return []
        case .invalidFrameParameters:
            return [
                "Only write binary or continuation frames that are non-final"
            ]
        case .invalidBufferSize:
            return [
                "Do not write an empty set of bytes"
            ]
        case .invalidRequest:
            return []
        case .invalidSubprotocol:
            return [
                "The request should inform at least one of the subprotocols defined by the server"
            ]
        }
    }
    
    /// A description of the problem
    public var reason: String {
        switch problem {
        case .invalidURI:
            return "The URI was invalid for WebSocket connections"
        case .parserError:
            return "The parser had an internal error"
        case .cannotConnect:
            return "The URI could not be connected to"
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
        case .invalidSubprotocol:
            return "The requested subprotocols are not defined by the WebSocket server."
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
        self.stackTrace = WebSocketError.makeStackTrace()
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
        /// The URI was invalid for WebSocket connections
        case invalidURI
        
        /// The parser had an internal error
        case parserError
        
        /// The URI could not be connected to
        case cannotConnect
        
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

        /// The upgrade request doesn't have any of the right subprotocol
        case invalidSubprotocol
    }
}
