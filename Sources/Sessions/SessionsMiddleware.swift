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
    let cookieName: String

    public init(
        _ sessions: SessionsProtocol,
        cookieName: String? = nil
    ) {
        self.sessions = sessions
        self.cookieName = cookieName ?? "vapor-session"
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
        
        request.set(session)


        let response = try chain.respond(to: request)

        if session.shouldDestroy {
            try sessions.destroy(identifier: session.identifier)
        } else {
            response.cookies[cookieName] = session.identifier
            try sessions.set(session)
        }

        return response
    }
    
}
