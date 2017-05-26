import HTTP
import Cookies

/// Looks for the `vapor-session` cookie on incoming
/// requests and attempts to initialize a Session based on the
/// identifier found.
///
/// If an active Session is found on the request when the response
/// is being made, the Session identifier is returned as a `vapor-session` cookie.
public final class SessionsMiddleware: Middleware {
    let sessions: SessionsProtocol
    let cookieFactory: CookieFactory
    let cookieName: String
    
    public typealias CookieFactory = (_ request: Request) throws -> Cookie

    /// Creates a new SessionsMiddleware.
    /// Note: The `name` and `value` properties of cookies
    /// created by the optional `cookieFactory` will be overwritten.
    /// To change the cookie's name, you must set the `cookieName` option
    /// in this init method. The cookie's value will always be the session id.
    public init(
        _ sessions: SessionsProtocol,
        cookieName: String = "vapor-session",
        cookieFactory: CookieFactory? = nil
    ) {
        self.sessions = sessions
        self.cookieName = cookieName
        self.cookieFactory = cookieFactory ?? { req in
            return Cookie(
                name: cookieName,
                value: "",
                httpOnly: true
            )
        }
    }

    public func respond(to request: Request, chainingTo chain: Responder) throws -> Response {
        let session: Session
        
        if
            let identifier = request.cookies[cookieName],
            let s = try sessions.get(identifier: identifier)
        {
            session = s
        } else {
            session = Session(identifier: try sessions.makeIdentifier())
        }
        
        request.session = session

        let response = try chain.respond(to: request)
        
        var cookie = try cookieFactory(request)
        if cookie.name != cookieName {
            // FIXME: future version of API should disallow this
            cookie.name = cookieName
        }
        cookie.value = session.identifier

        if session.shouldDestroy {
            try sessions.destroy(identifier: session.identifier)
        } else if session.shouldCreate {
            response.cookies.insert(cookie)
            try sessions.set(session)
        }

        return response
    }
    
}
