/**
    Looks for the `vapor-session` cookie on incoming
    requests and attempts to initialize a Session based on the
    identifier found.

    If an active Session is found on the request when the response
    is being made, the Session identifier is returned as a `vapor-session` cookie.
*/
class SessionMiddleware: Middleware {

    var driver: SessionDriver

    init(session: SessionDriver) {
        driver = session
    }

    func handle(_ handler: Request.Handler) -> Request.Handler {
        return { request in
            if
                let sessionIdentifier = request.cookies["vapor-session"]
                where self.driver.contains(identifier: sessionIdentifier)
            {
                request.session = Session(identifier: sessionIdentifier, driver: self.driver)
            } else {
                request.session = Session(driver: self.driver)
            }

            var response = try handler(request).makeResponse()

            if let identifier = request.session?.identifier {
                response.cookies["vapor-session"] = identifier
            }

            return response
        }
    }

}
