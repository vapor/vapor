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
    public static let resetContent = HTTPStatus(code:205, staticMessage: "Reset Content")
    public static let partialContent = HTTPStatus(code: 206, staticMessage: "Partial Content")

    // MARK - 3xx Redirection
    
    public static let multipleChoices = HTTPStatus(code: 300, staticMessage: "Multiple Choices")
    public static let movedPermanently = HTTPStatus(code: 301, staticMessage: "Moved Permanently")
    public static let found = HTTPStatus(code: 302, staticMessage: "Found")
    public static let seeOther = HTTPStatus(code: 303, staticMessage: "See Other")
    public static let notModified = HTTPStatus(code: 304, staticMessage: "Not modified")
    public static let useProxy = HTTPStatus(code: 305, staticMessage: "Use Proxy")
    public static let switchProxy = HTTPStatus(code: 306, staticMessage: "Switch Proxy")
    public static let temporaryRedirect = HTTPStatus(code: 307, staticMessage: "Temporary Redirect")
    public static let permanentRedirect = HTTPStatus(code: 308, staticMessage: "Permanent Redirect")

    // MARK - 4xx Client Error
    
    public static let badRequest = HTTPStatus(code: 400, staticMessage: "Bad Request")
    public static let unauthorized = HTTPStatus(code: 401, staticMessage: "Unauthorized")
    public static let forbidden = HTTPStatus(code: 403, staticMessage: "Forbidden")
    public static let notFound = HTTPStatus(code: 404, staticMessage: "Not Found")
    public static let methodNotAllowed = HTTPStatus(code: 405, staticMessage: "Method Not Allowed")
    public static let notAcceptable = HTTPStatus(code: 406, staticMessage: "Not Acceptable")
    public static let proxyAuthenticationRequired = HTTPStatus(code: 407, staticMessage: "Proxy Authentication Required")
    public static let requestTimeout = HTTPStatus(code: 408, staticMessage: "Request Timeout")
    public static let conflict = HTTPStatus(code: 409, staticMessage: "Conflict")
    public static let gone = HTTPStatus(code: 410, staticMessage: "Gone")
    public static let lengthRequired = HTTPStatus(code: 411, staticMessage: "Length Required")
    public static let preconditionFailed = HTTPStatus(code: 412, staticMessage: "Precondition Failed")
    public static let requestEntityTooLarge = HTTPStatus(code: 413, staticMessage: "Payload Too Large")
    public static let requestURITooLong = HTTPStatus(code: 414, staticMessage: "URI Too Long")
    public static let unsupportedMediaType = HTTPStatus(code: 415, staticMessage: "Unsupported Media Type")
    public static let requestedRangeNotSatisfiable = HTTPStatus(code: 416, staticMessage: "Requested Range Not Satisfiable")
    public static let expectationFailed = HTTPStatus(code: 417, staticMessage: "Expectation Failed")
    public static let imATeapot = HTTPStatus(code: 418, staticMessage: "I'm a teapot")
    public static let authenticationTimeout = HTTPStatus(code: 419, staticMessage: "Authentication Timeout")
    public static let enhanceYourCalm = HTTPStatus(code: 420, staticMessage: "Enhance Your Calm")
    public static let misdirectedRequest = HTTPStatus(code: 421, staticMessage: "Misdirected Request")
    public static let unprocessableEntity  = HTTPStatus(code: 422, staticMessage: "Unprocessable Entity")
    public static let locked = HTTPStatus(code: 423, staticMessage: "Locked")
    public static let failedDependency = HTTPStatus(code: 424, staticMessage: "Failed Dependency")
    public static let upgradeRequired = HTTPStatus(code: 426, staticMessage: "Upgrade Required")
    public static let preconditionRequired = HTTPStatus(code: 428, staticMessage: "Precondition Required")
    public static let tooManyRequests = HTTPStatus(code: 429, staticMessage: "Too Many Requests")
    public static let requestHeaderFieldsTooLarge = HTTPStatus(code: 431, staticMessage: "Request Header Fields Too Large")
    public static let unavailableForLegalReasons = HTTPStatus(code: 451, staticMessage: "Unavailable For Legal Reasons")

    // MARK - 5xx Server Error
    
    public static let internalServerError = HTTPStatus(code: 500, staticMessage: "Internal Server Error")
    public static let notImplemented = HTTPStatus(code: 501, staticMessage: "Not Implemented")
    public static let badGateway = HTTPStatus(code: 502, staticMessage: "Bad Gateway")
    public static let serviceUnavailable = HTTPStatus(code: 503, staticMessage: "Service Unavailable")
    public static let gatewayTimeout = HTTPStatus(code: 504, staticMessage: "Gateway Timeout")
    public static let httpVersionNotSupported = HTTPStatus(code: 505, staticMessage: "HTTP Version Not Supported")
    public static let variantAlsoNegotiates = HTTPStatus(code: 506, staticMessage: "Variant Also Negotiates")
    public static let insufficientStorage = HTTPStatus(code: 507, staticMessage: "Insufficient Storage")
    public static let loopDetected = HTTPStatus(code: 508, staticMessage: "Loop Detected")
    public static let notExtended = HTTPStatus(code: 510, staticMessage: "Not Extended")
    public static let networkAuthenticationRequired = HTTPStatus(code: 511, staticMessage: "Network Authentication Required")
}
