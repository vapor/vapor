import Foundation

/// A Redis error
public struct RedisError: Error {
    /// The error message
    public let string: String
}

/// A Redis primitive value
public indirect enum RedisValue {
    /// Initializes a bulk string from a String
    public init(bulk: String) {
        self = .bulkString(Data(bulk.utf8))
    }
    
    case null
    case basicString(String)
    case bulkString(Data)
    case error(RedisError)
    case integer(Int)
    case array([RedisValue])
    
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

extension RedisValue: ExpressibleByStringLiteral {
    /// Initializes a bulk string from a String literal
    public init(stringLiteral value: String) {
        self = .bulkString(Data(value.utf8))
    }
}

extension RedisValue: ExpressibleByArrayLiteral {
    /// Initializes an array from an Array literal
    public init(arrayLiteral elements: RedisValue...) {
        self = .array(elements)
    }
}

extension RedisValue: ExpressibleByNilLiteral {
    /// Initializes null from a nil literal
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension RedisValue: ExpressibleByIntegerLiteral {
    /// Initializes an integer from an integer literal
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}
