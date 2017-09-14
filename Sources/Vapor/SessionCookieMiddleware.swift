import Core
import HTTP

/// Checks the cookies for each `Request`
public final class SessionCookieMiddleware: Middleware {
    /// The cookie to look for
    let cookieName: String

    /// Fallback handler when the `Cookie` is missing
    public var missingCookie: ((Request) throws -> (Response))
    
    /// Checks the `Cookie.Value` for each `Request`
    public var cookieValidator: ((Cookie.Value) throws -> ())
    
    /// Creates a new `SessionCookieMiddleware` that can validate `Request`s
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
