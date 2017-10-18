import Debugging

public struct MySQLError : Swift.Error, Debuggable, Traceable, Helpable {
    public var possibleCauses: [String] {
        switch problem {
        case .invalidCredentials:
            return [
                "The username, database and/or password was invalid."
            ]
        case .connectionInUse:
            return [
                "The connection is already being used by another query."
            ]
        default:
            return []
        }
    }
    
    public var suggestedFixes: [String] {
        switch problem {
        case .invalidCredentials:
            return [
                "If you're not using a password on this user, set the password to `nil`, rather than an empty string (\"\")"
            ]
        case .connectionInUse:
            return [
                "If you're manually managing your connections, ensure a single connection is not used for more than one query at a time.",
                "If you're not managing connections yourself and are using the ConnectionPool instead, please file a bug report."
            ]
        default:
            return []
        }
    }
    
    /// A description of the problem
    public var reason: String {
        switch problem {
        case .invalidPacket: return "The received packet was invalid"
        case .invalidHandshake: return "The server's handshake was invalid"
        case .invalidResponse: return "The packet could not be parsed into valid a response"
        case .unsupported: return "This feature is not (yet) supported"
        case .parsingError: return "The binary format was not successfully parsed"
        case .decodingError: return "The received data did not correctly decode into a `Decodable`"
        case .connectionInUse: return "Connections can't be used twice at the same time. Communicate using a separate connection or though the connection pool instead."
        case .invalidCredentials: return "Authentication was not successful"
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
    enum Problem : String {
        case invalidPacket
        case invalidHandshake
        case invalidResponse
        case unsupported
        case parsingError
        case decodingError
        case connectionInUse
        case invalidCredentials
    }
}
