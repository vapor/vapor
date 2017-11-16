import Foundation

/// The HTTP response status
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/status/)
public struct Status: Codable, ExpressibleByIntegerLiteral, Equatable {
    /// Checks of two Statuses are equal
    public static func ==(lhs: Status, rhs: Status) -> Bool {
        return lhs.code == rhs.code
    }

    /// The HTTP status code
    public var code: Int

    public var message: String {
        get {
            return String(data: messageData, encoding: .utf8) ?? ""
        }
        set {
            self.messageData = Data(newValue.utf8)
        }
    }
    
    public private(set) var messageData: Data

    /// Creates a new (custom) status code
    public init(code: Int, message: String = "") {
        self.code = code 
        self.messageData = Data(message.utf8)
    }
    
    /// Creates a new statis code using an efficient StaticString
    init(code: Int, staticMessage: StaticString) {
        self.code = code
        self.messageData = Data(bytes: staticMessage.utf8Start, count: staticMessage.utf8CodeUnitCount)
    }

    /// Creates a new status from an integer literal
    public init(integerLiteral value: Int) {
        self.init(code: value)
    }
    
    // MARK - 1xx Informational
    
    public static let upgrade = Status(code: 101, staticMessage: "Upgrade")
    
    // MARK - 2xx Success
    
    public static let ok = Status(code: 200, staticMessage: "OK")
    public static let created = Status(code: 201, staticMessage: "Created")
    public static let accepted = Status(code: 202, staticMessage: "Accepted")
    public static let noContent = Status(code: 204, staticMessage: "No Content")
    
    // MARK - 3xx Redirection
    
    public static let multipleChoices = Status(code: 300, staticMessage: "Multiple Choices")
    public static let movedPermanently = Status(code: 301, staticMessage: "Moved Permanently")
    public static let found = Status(code: 302, staticMessage: "Found")
    
    // MARK - 4xx Client Error
    
    public static let badRequest = Status(code: 400, staticMessage: "Bad Request")
    public static let unauthorized = Status(code: 401, staticMessage: "Unauthorized")
    public static let forbidden = Status(code: 403, staticMessage: "Forbidden")
    public static let notFound = Status(code: 404, staticMessage: "Not Found")
    public static let notAcceptable = Status(code: 406, staticMessage: "Not Acceptable")
    
    // MARK - 5xx Server Error
    
    public static let internalServerError = Status(code: 500, staticMessage: "Internal Server Error")
    public static let notImplemented = Status(code: 501, staticMessage: "Not Implemented")
    public static let serviceUnavailable = Status(code: 500, staticMessage: "Service Unavailable")
}
