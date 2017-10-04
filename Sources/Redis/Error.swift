public struct RedisError: Error {
    public let string: String
}

enum ClientError: Error {
    case invalidTypeToken
    case parsingError
    case unexpectedResult(RedisValue)
}
