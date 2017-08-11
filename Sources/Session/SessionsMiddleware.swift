import HTTP
import Cookies
import Service

/// Looks for the `vapor-session` cookie on incoming
/// requests and attempts to initialize a Session based on the
/// identifier found.
///
/// If an active Session is found on the request when the response
/// is being made, the Session identifier is returned as a `vapor-session` cookie.
public final class SessionsMiddleware: Middleware {
    /// The sessions manager used to store and fetch sessions.
    let sessions: Sessions

    /// The unique name of the cookie to be stored
    /// in the browser. This will be visible when inspecting
    /// browser cookies.
    let cookieName: String

    /// Cookies will pass through this modifier
    /// before being sent to the browser. This is
    /// your chance to change them however you see fit.
    /// - Note: Do not change the name/value.
    let cookieModifier: CookieModifier

    /// Allows user to modify cookie.
    public typealias CookieModifier = (Cookie) throws -> Cookie

    /// Creates a new SessionsMiddleware.
    /// Note: The `name` and `value` properties of cookies
    /// created by the optional `cookieFactory` will be overwritten.
    /// To change the cookie's name, you must set the `cookieName` option
    /// in this init method. The cookie's value will always be the session id.
    public init(
        sessions: Sessions,
        cookieName: String = "vapor-session",
        cookieModifier: CookieModifier? = nil
    ) {
        self.sessions = sessions
        self.cookieName = cookieName
        self.cookieModifier = cookieModifier ?? { $0 }
    }

    /// Responds to the request.
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

        var cookie = Cookie(name: cookieName, value: session.identifier)
        cookie = try cookieModifier(cookie)

        if session.shouldDestroy {
            try sessions.destroy(identifier: session.identifier)
        } else if session.shouldCreate {
            response.cookies.insert(cookie)
            try sessions.set(session)
        }

        return response
    }
    
}

// MARK: Service

extension SessionsMiddleware: ServiceType {
    /// See Service.serviceName
    public static var serviceName: String {
        return "sessions"
    }

    /// See Service.serviceSupports
    public static var serviceSupports: [Any.Type] {
        return [Middleware.self]
    }

    /// See Service.makeService()
    public static func makeService(for container: Container) throws -> SessionsMiddleware? {
        return try SessionsMiddleware(
            sessions: container.make()
        )
    }
}

