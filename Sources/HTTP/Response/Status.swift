/// The HTTP response status
///
/// http://localhost:8000/http/status/
public struct Status: Codable, ExpressibleByIntegerLiteral, Equatable {
    /// Checks of two Statuses are equal
    public static func ==(lhs: Status, rhs: Status) -> Bool {
        return lhs.code == rhs.code
    }

    /// The HTTP status code
    public var code: Int

    public var message: String

    /// Creates a new (custom) status code
    public init(code: Int, message: String = "") {
        self.code = code 
        self.message = message
    }

    /// Creates a new status from an integer literal
    public init(integerLiteral value: Int) {
        self.init(code: value)
    }
    
    // MARK - 1xx Informational
    
    public static let upgrade = Status(code: 101, message: "Upgrade")
    
    // MARK - 2xx Success
    
    public static let ok = Status(code: 200, message: "OK")
    public static let created = Status(code: 201, message: "Created")
    public static let accepted = Status(code: 202, message: "Accepted")
    public static let noContent = Status(code: 204, message: "No Content")
    
    // MARK - 3xx Redirection
    
    public static let multipleChoices = Status(code: 300, message: "Multiple Choices")
    public static let movedPermanently = Status(code: 301, message: "Moved Permanently")
    public static let found = Status(code: 302, message: "Found")
    
    // MARK - 4xx Client Error
    
    public static let badRequest = Status(code: 400, message: "Bad Request")
    public static let unauthorized = Status(code: 401, message: "Unauthorized")
    public static let forbidden = Status(code: 403, message: "Forbidden")
    public static let notFound = Status(code: 404, message: "Not Found")
    public static let notAcceptable = Status(code: 406, message: "Not Acceptable")
    
    // MARK - 5xx Server Error
    
    public static let internalServerError = Status(code: 500, message: "Internal Server Error")
    public static let notImplemented = Status(code: 501, message: "Not Implemented")
    public static let serviceUnavailable = Status(code: 500, message: "Service Unavailable")
}
