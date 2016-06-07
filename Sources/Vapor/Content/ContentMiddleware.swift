class ContentMiddleware: Middleware {

    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        var request = request

        let query = Content.parseQuery(uri: request.uri)
        request.data = Content(query: query, request: request)
        request.query = query

        return try next.respond(to: request)
    }

}
