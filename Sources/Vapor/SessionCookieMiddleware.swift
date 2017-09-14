import Core
import HTTP

/// Adds the current `Date` to each `Response`
public final class SessionCookieMiddleware: Middleware {
    let cookieName: String
    
    public var missingCookie: ((Request) throws -> (Response))
    public var cookieValidator: ((Cookie.Value) throws -> ())
    
    public init(cookie: String, onRequest validate: @escaping ((Cookie.Value) throws -> ())) {
        self.cookieName = cookie
        self.cookieValidator = validate
        
        self.missingCookie = { request in
            return Response(status: 401)
        }
    }
    
    /// See `Middleware.respond`
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        guard let cookie = request.cookies[cookieName] else {
            return Future(try missingCookie(request))
        }
        
        try cookieValidator(cookie)
        
        return try next.respond(to: request)
    }
}
