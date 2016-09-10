import HTTP
import Cookies

private let cookieName = "vapor-sessions"

/**
    Looks for the `vapor-session` cookie on incoming
    requests and attempts to initialize a Session based on the
    identifier found.

    If an active Session is found on the request when the response
    is being made, the Session identifier is returned as a `vapor-session` cookie.
*/
public final class SessionsMiddleware: Middleware {

    var sessions: SessionsProtocol

    public init(sessions: SessionsProtocol) {
        self.sessions = sessions
    }

    public func respond(to request: Request, chainingTo chain: Responder) throws -> Response {

        let session = Session(sessions: sessions)
        if
            let identifier = request.cookies[cookieName],
            try sessions.contains(identifier)
        {
            session.identifier = identifier
        }

        request.storage["session"] = session

        let response = try chain.respond(to: request)

        if let identifier = session.identifier {
            response.cookies[cookieName] = identifier
        }

        return response
    }
    
}
