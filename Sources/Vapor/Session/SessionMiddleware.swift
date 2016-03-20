class SessionMiddleware: Middleware {

    static func handle(handler: Request.Handler, for application: Application) -> Request.Handler {
        return { request in
            if let sessionIdentifier = request.cookies["vapor-session"] {
            	request.session = Session(identifier: sessionIdentifier, driver: application.session)
            }

            let response = try handler(request: request)

            if let session = request.session {
            	response.cookies["vapor-session"] = session.identifier
            }

            return response
        }
    }

}
