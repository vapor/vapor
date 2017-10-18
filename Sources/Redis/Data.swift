import Foundation

/// A Redis error
public struct RedisError: Swift.Error {
    /// The error message
    public let string: String
}

/// A Redis primitive value
public indirect enum RedisData {
    /// Initializes a bulk string from a String
    public init(bulk: String) {
        self = .bulkString(Data(bulk.utf8))
    }
    
    case null
    case basicString(String)
    case bulkString(Data)
    case error(RedisError)
    case integer(Int)
    case array([RedisData])
    
    /// Extracts the basic/bulk string as a `String`.
    public var string: String? {
        switch self {
        case .basicString(let string):
            return string
        case .bulkString(let data):
            return String(bytes: data, encoding: .utf8)
        default:
            return nil
        }
    }
}

extension RedisData: ExpressibleByStringLiteral {
    /// Initializes a bulk string from a String literal
    public init(stringLiteral value: String) {
        self = .bulkString(Data(value.utf8))
    }
}

extension RedisData: ExpressibleByArrayLiteral {
    /// Initializes an array from an Array literal
    public init(arrayLiteral elements: RedisData...) {
        self = .array(elements)
    }
}

extension RedisData: ExpressibleByNilLiteral {
    /// Initializes null from a nil literal
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension RedisData: ExpressibleByIntegerLiteral {
    /// Initializes an integer from an integer literal
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}
