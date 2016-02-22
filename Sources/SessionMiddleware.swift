class SessionMiddleware: Middleware {

    static func handle(handler: Request.Handler) -> Request.Handler {
        return { request in
            Session.start(request)

            let response = try handler(request: request)

            Session.close(request: request, response: response)

            return response
        }
    }

}
