class SessionMiddleware: Middleware {

    static func handle(forApplication application: Application, handler: Request.Handler) -> Request.Handler {
        return { request in
            let sessionIdentifier = request.cookies["vapor-session"] ?? application.sessionDriver.makeSessionIdentifier()
            request.session.identifier = sessionIdentifier
            request.session.driver = application.sessionDriver

            let response = try handler(request: request)

            response.cookies["vapor-session"] = sessionIdentifier

            return response
        }
    }

}
