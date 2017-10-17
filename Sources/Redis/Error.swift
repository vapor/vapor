/// Client errors
enum ClientError: Error {
    /// Parsing the Value's token failed because the value's identifying token is unknown
    case invalidTypeToken
    
    /// Parsing the value failed. The protocol communication was invalid
    case parsingError
    
    /// The command's result was unexpected
    case unexpectedResult(RedisData)
}
