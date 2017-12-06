import Debugging
import Foundation

/// A response from the server
enum Response {
    struct State {
        let marker: UInt8
        let state: (UInt8, UInt8, UInt8, UInt8, UInt8)
    }
    
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        
        return nil
    }
    
    struct Error : Swift.Error, Traceable, Debuggable {
        var reason: String {
            return message
        }
        
        var identifier: String {
            return "remote-error"
        }
        
        let code: UInt16
        let state: State?
        let message: String
        public var file: String
        public var function: String
        public var line: UInt
        public var column: UInt
        public var stackTrace: [String]
        
        init(code: UInt16,
             state: State?,
             message: String,
             file: String = #file,
             function: String = #function,
             line: UInt = #line,
             column: UInt = #column
        ) {
            self.code = code
            self.state = state
            self.message = message
            self.file = file
            self.function = function
            self.line = line
            self.column = column
            self.stackTrace = Error.makeStackTrace()
        }
    }
    
    struct OK {
        let affectedRows: UInt64
        let lastInsertId: UInt64
        let status: UInt16?
        let warnings: UInt16?
        let data: Data
    }
    
    case error(Error)
    case ok(OK)
    case eof(OK)
}

/// Keeps track of capabilities. Which can be the server's, client's or combined capabilities
struct Capabilities : OptionSet, ExpressibleByIntegerLiteral {
    var rawValue: UInt32
    
    static let longPassword: Capabilities = 1
    static let longFlag: Capabilities = 4
    static let connectWithDB: Capabilities = 8
    static let protocol41: Capabilities = 512
    static let ssl: Capabilities = 2048
    static let secureConnection: Capabilities = 32_768
    
    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    init(integerLiteral value: UInt32) {
        self.rawValue = value
    }
}
