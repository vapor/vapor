class SessionMiddleware: Middleware {

    static func handle(handler: Request.Handler) -> Request.Handler {
        return { request in
            Session.start(request)

            let convertible = try handler(request: request)
            let response = convertible.response()
            
            Session.close(request: request, response: response)

            return response
        }
    }

}
