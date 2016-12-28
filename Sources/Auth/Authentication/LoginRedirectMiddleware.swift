import HTTP

public class LoginRedirectMiddleware: Middleware {
    public let loginRoute: String
    public init(loginRoute: String) {
        self.loginRoute = loginRoute
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard try request.subject().authenticated else {
            return Response(redirect: loginRoute)
        }

        return try next.respond(to: request)
    }
}
