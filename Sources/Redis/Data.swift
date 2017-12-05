import Foundation

/// A Redis primitive value
public struct RedisData {
    /// Internal storage abstraction
    indirect enum Storage {
        case null
        case basicString(String)
        case bulkString(Data)
        case error(RedisError)
        case integer(Int)
        case array([RedisData])
    }
    
    /// Stores the actual value so we don't have to break the API
    var storage: Storage
    
    /// Creates a new RedisData
    private init(storage: Storage) {
        self.storage = storage
    }
    
    /// Initializes a bulk string from a String
    public init(bulk: String) {
        self = .bulkString(Data(bulk.utf8))
    }
    
    /// Creates a BasicString. Used for command names and basic responses
    public static func basicString(_ string: String) -> RedisData {
        return RedisData(storage: .basicString(string))
    }
    
    /// Creates a textual bulk string, or a "normal" String
    public static func bulkString(_ string: String) -> RedisData {
        return RedisData(storage: .bulkString(Data(string.utf8)))
    }
    
    /// Creates a binary bulk string, or a "normal" Data
    public static func bulkString(_ data: Data) -> RedisData {
        return RedisData(storage: .bulkString(data))
    }
    
    /// Creates an array of redis data
    public static func array(_ data: [RedisData]) -> RedisData {
        return RedisData(storage: .array(data))
    }
    
    /// Creates a new Redis Integer Data
    public static func integer(_ int: Int) -> RedisData {
        return RedisData(storage: .integer(int))
    }
    
    /// Creates a redis Error
    public static func error(_ error: RedisError) -> RedisData {
        return RedisData(storage: .error(error))
    }
    
    /// Redis' Null
    public static let null = RedisData(storage: .null)
    
    /// Extracts the basic/bulk string as a `String`.
    public var string: String? {
        switch self.storage {
        case .basicString(let string):
            return string
        case .bulkString(let data):
            return String(bytes: data, encoding: .utf8)
        default:
            return nil
        }
    }
    
    /// Extracts the binary data from a Redis BulkString
    public var data: Data? {
        if case .bulkString(let data) = self.storage {
            return data
        }
        
        return nil
    }
    
    /// Extracts an array type from this data
    public var array: [RedisData]? {
        guard case .array(let array) = self.storage else {
            return nil
        }
        
        return array
    }
    
    /// Extracts an array type from this data
    public var int: Int? {
        guard case .integer(let int) = self.storage else {
            return nil
        }
        
        return int
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
