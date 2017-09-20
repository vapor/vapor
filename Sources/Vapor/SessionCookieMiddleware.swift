import Foundation
import Core
import HTTP

/// Checks the cookies for each `Request`
public final class SessionCookieMiddleware: Middleware {
    /// The cookie to work with
    let cookieName: String
    
    public typealias CookieFactory = ((Request) throws -> (Cookie.Value))
    public typealias CookieValidator = ((Cookie.Value) throws -> ())
    
    /// Creates new cookies
    public var cookieFactory: CookieFactory
    
    /// Checks the `Cookie.Value` for each `Request`
    public var cookieValidator: CookieValidator
    
    /// Creates a new `SessionCookieMiddleware` that can validate `Request`s
    public init(cookie: String, onRequest validate: @escaping CookieValidator) {
        self.cookieName = cookie
        self.cookieValidator = validate
        
        self.cookieFactory = { _ in
            return Cookie.Value(value: UUID().uuidString)
        }
    }
    
    /// See `Middleware.respond`
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        let cookie: Cookie.Value
        
        if let cookieValue = request.cookies[cookieName] {
            cookie = cookieValue
        } else {
            let cookieValue = try cookieFactory(request)
            request.cookies[cookieName] = cookieValue
            
            cookie = cookieValue
        }
        
        try cookieValidator(cookie)
        
        return try next.respond(to: request)
    }
}
