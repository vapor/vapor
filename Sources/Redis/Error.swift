public struct RedisError: Error {
    public let string: String
}

enum ClientError: Error {
    case invalidTypeToken
    case parsingError
}

indirect enum RedisValue {
    case null
    case notYetParsed
    case basicString(String)
    case bulkString(String)
    case error(RedisError)
    case integer(Int)
    case array([RedisValue])
    
    var string: String? {
        switch self {
        case .basicString(let string):
            return string
        case .bulkString(let string):
            return string
        default:
            return nil
        }
    }
}
