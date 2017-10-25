/// The HTTP response status
///
/// TODO: Add more status codes
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
    
    public static let upgrade = Status(code: 101, message: "Upgrade")
    public static let ok = Status(code: 200, message: "OK")
    public static let notFound = Status(code: 404, message: "Not Found")
    public static let internalServerError = Status(code: 500, message: "Internal Server Error")
}
