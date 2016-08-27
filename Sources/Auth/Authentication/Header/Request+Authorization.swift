import HTTP

extension Request {
    public func authorization() throws -> Authorization {
        guard let authorization = headers["Authorization"] else {
            throw AuthError.noAuthorizationHeader
        }

        return Authorization(header: authorization)
    }
}
