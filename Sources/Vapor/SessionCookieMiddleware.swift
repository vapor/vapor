import Foundation
import Async
import HTTP

/// Something that is convertible between a Cookie and an instance.
public protocol SessionCookie: CookieValueRepresentable, CookieValueInitializable {
    /// Validates if the session. For example to lock a session to an IP address.
    func validate(for request: Request) throws
}

extension Cookie.Value: SessionCookie {
    /// Always succeeds
    public func validate(for request: Request) throws {}
}

/// Checks the cookies for each `Request`
public final class SessionCookieMiddleware<SC: SessionCookie>: Middleware {
    /// The cookie to work with
    let cookieName: String
    
    /// Used to create new sessions
    public typealias SessionFactory = ((Request) throws -> (SC))
    
    /// Creates new cookies
    public var sessionFactory: SessionFactory
    
    /// Creates a new `SessionCookieMiddleware` that can validate `Request`s
    public init(cookie: String, sessionType: SC.Type = SC.self, factory: @escaping SessionFactory) {
        self.cookieName = cookie
        
        self.sessionFactory = factory
    }
    
    /// See `Middleware.respond`
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        let session: SC
        
        if let cookieValue = request.cookies[cookieName] {
            session = try SC.init(from: cookieValue)
        } else {
            let cookieValue = try sessionFactory(request)
            request.cookies[cookieName] = try cookieValue.makeCookieValue()
            session = cookieValue
        }
        
        try session.validate(for: request)
        
        request.extend["vapor:session-cookie:\(cookieName)"] = session
        request.extend["vapor:last-session-cookie"] = session
        
        return try next.respond(to: request)
    }
}
