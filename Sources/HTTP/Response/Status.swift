import Foundation
import Bits

/// The HTTP response status
///
/// They can be created from a premade code or using an integer literal
///
///     let status = Status.ok
///
///     let statusLiteral: Status = 200
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/status/)
public struct HTTPStatus: Codable, ExpressibleByIntegerLiteral, Equatable {
    /// Checks of two Statuses are equal
    public static func ==(lhs: HTTPStatus, rhs: HTTPStatus) -> Bool {
        return lhs.code == rhs.code
    }

    /// The HTTP status code
    public var code: Int

    public var message: String {
        get {
            return String(bytes: messageBytes, encoding: .utf8) ?? ""
        }
        set {
            self.messageBytes = [UInt8](newValue.utf8)
        }
    }
    
    internal private(set) var messageBytes: [UInt8]
    
    /// Creates a new (custom) status code
    public init(code: Int, message: String = "") {
        self.code = code 
        self.messageBytes = [UInt8](message.utf8)
    }
    
    /// Creates a new statis code using an efficient StaticString
    init(code: Int, staticMessage: StaticString) {
        self.code = code
        self.messageBytes = Array(
            ByteBuffer(start: staticMessage.utf8Start, count: staticMessage.utf8CodeUnitCount)
        )
    }

    /// Creates a new status from an integer literal
    public init(integerLiteral value: Int) {
        self.init(code: value)
    }
    
    // MARK - 1xx Informational
    
    public static let upgrade = HTTPStatus(code: 101, staticMessage: "Upgrade")
    
    // MARK - 2xx Success
    
    public static let ok = HTTPStatus(code: 200, staticMessage: "OK")
    public static let created = HTTPStatus(code: 201, staticMessage: "Created")
    public static let accepted = HTTPStatus(code: 202, staticMessage: "Accepted")
    public static let noContent = HTTPStatus(code: 204, staticMessage: "No Content")
    
    // MARK - 3xx Redirection
    
    public static let multipleChoices = HTTPStatus(code: 300, staticMessage: "Multiple Choices")
    public static let movedPermanently = HTTPStatus(code: 301, staticMessage: "Moved Permanently")
    public static let found = HTTPStatus(code: 302, staticMessage: "Found")
    public static let seeOther = HTTPStatus(code: 303, staticMessage: "See Other")
    public static let notModified = HTTPStatus(code: 304, staticMessage: "Not modified")
    public static let temporaryRedirect = HTTPStatus(code: 307, staticMessage: "Temporary Redirect")
    
    // MARK - 4xx Client Error
    
    public static let badRequest = HTTPStatus(code: 400, staticMessage: "Bad Request")
    public static let unauthorized = HTTPStatus(code: 401, staticMessage: "Unauthorized")
    public static let forbidden = HTTPStatus(code: 403, staticMessage: "Forbidden")
    public static let notFound = HTTPStatus(code: 404, staticMessage: "Not Found")
    public static let notAcceptable = HTTPStatus(code: 406, staticMessage: "Not Acceptable")
    
    // MARK - 5xx Server Error
    
    public static let internalServerError = HTTPStatus(code: 500, staticMessage: "Internal Server Error")
    public static let notImplemented = HTTPStatus(code: 501, staticMessage: "Not Implemented")
    public static let serviceUnavailable = HTTPStatus(code: 503, staticMessage: "Service Unavailable")
}
