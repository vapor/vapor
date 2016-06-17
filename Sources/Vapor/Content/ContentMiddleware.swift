class ContentMiddleware: HTTP.Middleware {

    func respond(to request: HTTP.Request, chainingTo next: HTTP.Responder) throws -> HTTP.Response {
        request.data = Content(request)
        return try next.respond(to: request)
    }

}
