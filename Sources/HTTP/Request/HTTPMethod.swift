import Foundation
import Bits

/// An HTTP Request method
///
/// Used to provide information about the kind of action being requested
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/method/)
public struct HTTPMethod : Equatable, Hashable, Codable, CustomDebugStringConvertible, ExpressibleByStringLiteral {
    /// Decodes a method from a String
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let string = try container.decode(String.self).uppercased()

        self.init(string)
    }

    /// Debug helper, allows you to `po` a method and get it's debugDescription
    public var debugDescription: String {
        return string
    }

    /// Represents this method as a String
    public var string: String {
        get {
            return String(bytes: self.bytes, encoding: .utf8) ?? ""
        }
        set {
            self.bytes = [UInt8](newValue.utf8)
        }
    }
    
    public private(set) var bytes: [UInt8]

    /// Encodes this method to a String
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.string)
    }

    /// A GET request is used to retrieve information, such as a web-page or profile picture
    ///
    /// GET Requests will not provide a body
    public static let get = HTTPMethod(staticString: "GET")

    /// PUT is used to overwrite information.
    ///
    /// `PUT /users/1` is should replace the information for the user with ID `1`
    ///
    /// It may create a new entity if the requested entity didn't exist.
    public static let put = HTTPMethod(staticString: "PUT")

    /// POST is used to create a new entity, such as a reaction in the comment section
    ///
    /// One of the more common methods, since it's also used to create new users and log in existing users
    public static let post = HTTPMethod(staticString: "POST")

    /// DELETE is an action that... deletes an entity.
    ///
    /// DELETE requests cannot provide a body
    public static let delete = HTTPMethod(staticString: "DELETE")

    /// PATCH is similar to PUT in that it updates an entity.
    ///
    /// ..but where PUT replaces an entity, PATCH only updated the specified fields
    public static let patch = HTTPMethod(staticString: "PATCH")


    /// OPTIONS is used by the browser to check if the conditions allow a specific request.
    ///
    /// Often used for secutity purposes.
    public static let options = HTTPMethod(staticString: "OPTIONS")
    
    /// A hashValue is useful for using the method in a dictionary
    public var hashValue: Int {
        return Data(bytes).hashValue
    }

    /// Compares two methods to be equal
    public static func ==(lhs: HTTPMethod, rhs: HTTPMethod) -> Bool {
        return lhs.bytes == rhs.bytes
    }
    
    /// Creates a new method from a StaticString
    init(staticString: StaticString) {
        self.bytes = Array(
            ByteBuffer(start: staticString.utf8Start, count: staticString.utf8CodeUnitCount)
        )
    }

    /// Creates a new method from a String
    public init(_ string: String) {
        switch string.uppercased() {
        case "GET": self = .get
        case "PUT": self = .put
        case "POST": self = .post
        case "PATCH": self = .patch
        case "DELETE": self = .delete
        case "OPTIONS": self = .options
        default:
            self.bytes = [UInt8](string.utf8)
        }
    }

    /// Instantiate a Method from a String literal
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Instantiate a Method from a String literal
    public init(unicodeScalarLiteral value: String) {
        self.init(value)
    }

    /// Instantiate a Method from a String literal
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(value)
    }
}
