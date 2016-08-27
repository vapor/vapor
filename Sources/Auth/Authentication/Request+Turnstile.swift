import Turnstile
import HTTP

public enum AuthError: Swift.Error {
    case noUser
    case invalidBasicAuthorization
    case invalidBearerAuthorization
    case noAuthorizationHeader
    case notAuthenticated
}

public extension Request {
    public func user() throws -> Subject {
        guard let user = storage["auth:user"] as? Subject else {
            throw AuthError.noUser
        }

        return user
    }
}
