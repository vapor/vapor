class ContentMiddleware: HTTP.Middleware {

    func respond(to request: HTTP.Request, chainingTo next: HTTP.Responder) throws -> HTTP.Response {
        // mutable -- MUST be declared at top of function
        let request = request

        // TODO: 
//        request.data = Content(request: request)

        return try next.respond(to: request)
    }

}
