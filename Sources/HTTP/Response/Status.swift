/// The HTTP response status
///
/// TODO: Add more status codes
public enum Status: Codable, ExpressibleByIntegerLiteral, Equatable {
    /// upgrade is used for upgrading the connection to a new protocol, such as WebSocket or HTTP/2
    case upgrade
    /// A successful response
    case ok
    /// The resource has not been found
    case notFound
    /// An internal error occurred
    case internalServerError
    /// Something yet to be implemented
    case custom(code: Int, message: String)

    enum CodingKeys: CodingKey {
        case code, message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            code: container.decode(Int.self, forKey: .code),
            message: container.decode(String.self, forKey: .message)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
    }

    /// Checks of two Statuses are equal
    public static func ==(lhs: Status, rhs: Status) -> Bool {
        return lhs.code == rhs.code
    }

    /// The HTTP status code
    public var code: Int {
        switch self {
        case .upgrade: return 101
        case .ok: return 200
        case .notFound: return 404
        case .internalServerError: return 500
        case .custom(let code, _): return code
        }
    }

    public var message: String {
        switch self {
        case .upgrade: return "Upgrade"
        case .ok: return "OK"
        case .notFound: return "Not Found"
        case .internalServerError: return "Internal Server Error"
        case .custom(_, let message): return message
        }
    }

    /// Creates a new (custom) status code
    public init(code: Int, message: String = "") {
        switch code {
        case 101: self = .upgrade
        case 200: self = .ok
        case 404: self = .notFound
        case 500: self = .internalServerError
        default: self = .custom(code: code, message: message)
        }
    }

    /// Creates a new status from an integer literal
    public init(integerLiteral value: Int) {
        self.init(code: value)
    }
}
