class SessionMiddleware: Middleware {

    static func handle(handler: Request.Handler, for application: Application) -> Request.Handler {
        return { request in
            let sessionIdentifier = request.cookies["vapor-session"] ?? application.sessionDriver.makeSessionIdentifier()
            request.session = Session(identifier: sessionIdentifier, driver: application.sessionDriver)

            let response = try handler(request: request)

            response.cookies["vapor-session"] = sessionIdentifier

            return response
        }
    }

}
