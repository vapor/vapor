/**
    Looks for the `vapor-session` cookie on incoming
    requests and attempts to initialize a Session based on the
    identifier found.

    If an active Session is found on the request when the response
    is being made, the Session identifier is returned as a `vapor-session` cookie.
*/
class SessionMiddleware: Middleware {

    func respond(request: Request, chain: Responder) throws -> Response {
        guard let app = request.app else {
            return try chain.respond(request)
        }

        var request = request

        if let sessionIdentifier = request.cookies["vapor-session"] {
            request.session = Session(identifier: sessionIdentifier, driver: app.session)
        } else {
            request.session = Session(driver: app.session)
        }

        var response = try chain.respond(request)

        if let identifier = request.session?.identifier {
            response.cookies["vapor-session"] = identifier
        }

        return response
    }

}
