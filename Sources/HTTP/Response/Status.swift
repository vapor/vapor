/// The HTTP response status
///
/// TODO: Add more status codes
public struct Status: Codable, ExpressibleByIntegerLiteral, Equatable {
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
    
    public static let upgrade = Status(code: 101, message: "UPGRADE")
    public static let ok = Status(code: 200, message: "OK")
    public static let notFound = Status(code: 404, message: "NOT FOUND")
    public static let internalServerError = Status(code: 500, message: "INTERNAL SERVER ERROR")
}
