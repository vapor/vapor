import Foundation

indirect enum _RedisValue {
    case notYetParsed
    case parsing([_RedisValue])
    case parsed(RedisValue)
}

public indirect enum RedisValue {
    init(bulk: String) {
        self = .bulkString(Data(bulk.utf8))
    }
    
    case null
    case basicString(String)
    case bulkString(Data)
    case error(RedisError)
    case integer(Int)
    case array([RedisValue])
    
    var string: String? {
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
    public init(stringLiteral value: String) {
        self = .bulkString(Data(value.utf8))
    }
}

extension RedisValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: RedisValue...) {
        self = .array(elements)
    }
}

extension RedisValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension RedisValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}
