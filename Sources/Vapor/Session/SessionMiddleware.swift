/**
    Looks for the `vapor-session` cookie on incoming
    requests and attempts to initialize a Session based on the 
    identifier found.

    If an active Session is found on the request when the response
    is being made, the Session identifier is returned as a `vapor-session` cookie.
*/
class SessionMiddleware: Middleware {

    static func handle(handler: Request.Handler, for app: Application) -> Request.Handler {
        return { request in
            if let sessionIdentifier = request.cookies["vapor-session"] {
                request.session = Session(identifier: sessionIdentifier, driver: app.session)
            } else {
                request.session = Session(driver: app.session)
            }

            let response = try handler(request: request)

            if let identifier = request.session?.identifier {
                response.cookies["vapor-session"] = identifier
            }

            return response
        }
    }

}
