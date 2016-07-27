import Engine

/**
    Looks for the `vapor-session` cookie on incoming
    requests and attempts to initialize a Session based on the
    identifier found.

    If an active Session is found on the request when the response
    is being made, the Session identifier is returned as a `vapor-session` cookie.
*/
class SessionMiddleware: Middleware {

    var sessions: Sessions

    init(sessions: Sessions) {
        self.sessions = sessions
    }

    func respond(to request: HTTPRequest, chainingTo chain: HTTPResponder) throws -> HTTPResponse {
        // mutable -- MUST be declared at top of function
        if
            let identifier = request.cookies["vapor-session"],
            sessions.contains(identifier: identifier)
        {
            request.session = Session(identifier: identifier, sessions: sessions)
        } else {
            request.session = Session(sessions: sessions)
        }

        let response = try chain.respond(to: request)

        if let identifier = request.session?.identifier {
            response.cookies["vapor-session"] = identifier
        }

        return response
    }

}
