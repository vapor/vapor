enum MySQLError : Error {
    case invalidPacket
    case invalidHandshake
    case invalidResponse
    case unauthenticated
    case unsupported
    case parsingError
    case decodingError
    case connectionInUse
    case invalidCredentials
}
