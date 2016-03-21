class SessionMiddleware: Middleware {

    static func handle(handler: Request.Handler, for app: Application) -> Request.Handler {
        return { request in
            if let sessionIdentifier = request.cookies["vapor-session"] {
            	request.session = Session(identifier: sessionIdentifier, driver: app.session)
            } else {
                request.session = Session(driver: app.session)
            }

            let response = try handler(request: request)

            if let session = request.session where session.enabled {
            	response.cookies["vapor-session"] = session.identifier
            }

            return response
        }
    }

}
