class SessionMiddleware: Middleware {

    static func handle(handler: Request.Handler) -> Request.Handler {
        return { request in
            let sessionIdentifier = request.cookies["vapor-session"] ?? Session.driver.makeSessionIdentifier()
            request.session.identifier = sessionIdentifier

            let response = try handler(request: request)

            response.cookies["vapor-session"] = sessionIdentifier

            return response
        }
    }

}
