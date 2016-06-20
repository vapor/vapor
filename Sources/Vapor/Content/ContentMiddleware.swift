class ContentMiddleware: Middleware {

    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        // mutable -- MUST be declared at top of function
        var request = request

        request.data = Content(request: request)

        return try next.respond(to: request)
    }

}
