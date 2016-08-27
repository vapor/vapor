import HTTP
import Middleware

public class ProtectMiddleware: Middleware {
    public init() {}
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard try request.subject().authenticated else {
            throw AuthError.notAuthenticated
        }

        return try next.respond(to: request)
    }
}
