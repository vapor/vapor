import Debugging

public struct MySQLError : Swift.Error, Debuggable, Traceable {
    /// A description of the problem
    public var reason: String {
        switch problem {
        case .invalidQuery(let code): return "MySQL error code \(code)"
        case .invalidPacket: return "The received packet was invalid"
        case .invalidHandshake: return "The server's handshake was invalid"
        case .invalidResponse: return "The packet could not be parsed into valid a response"
        case .unsupported: return "This feature is not (yet) supported"
        case .parsingError: return "The binary format was not successfully parsed"
        case .decodingError: return "The received data did not correctly decode into a `Decodable`"
        case .connectionInUse: return "Connections can't be used twice at the same time. Communicate using a separate connection or though the connection pool instead."
        case .invalidCredentials: return "Authentication was not successful"
        case.tooManyParametersBound: return "More parameters were bound than specified in the query"
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
        self.stackTrace = MySQLError.makeStackTrace()
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.problem = problem
    }
    
    init(
        packet: Packet,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.stackTrace = MySQLError.makeStackTrace()
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        
        if let code = try? Parser(packet: packet, position: 1).parseUInt16() {
            self.problem = .invalidQuery(code)
        } else {
            self.problem = .decodingError
        }
    }
    
    /// The file this occurred in
    public let file: String
    
    /// The function this occurred from
    public let function: String
    
    /// The line this occurred at
    public let line: UInt
    
    /// The column this occurred at
    public let column: UInt
    
    /// Which problem
    internal let problem: Problem
    
    /// The problem
    enum Problem {
        var rawValue: String {
            switch self {
            case .invalidQuery(_): return "invalidQuery"
            case .invalidPacket: return "invalidPacket"
            case .invalidHandshake: return "invalidHandshake"
            case .invalidResponse: return "invalidResponse"
            case .unsupported: return "unsupported"
            case .parsingError: return "parsingError"
            case .decodingError: return "decodingError"
            case .connectionInUse: return "connectionInuse"
            case .invalidCredentials: return "invalidCredentials"
            case .tooManyParametersBound: return "tooManyParametersBound"
            }
        }
        
        case invalidQuery(UInt16)
        case invalidPacket
        case invalidHandshake
        case invalidResponse
        case unsupported
        case parsingError
        case decodingError
        case connectionInUse
        case invalidCredentials
        case tooManyParametersBound
    }
}
