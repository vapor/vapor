class QueryMiddleware: Middleware {

    func respond(to request: HTTP.Request, chainingTo next: HTTP.Responder) throws -> HTTP.Response {
        // mutable -- MUST be declared at top of function
        var request = request

        if let queryString = request.uri.query {
            request.query = StructuredData(formURLEncoded: queryString.data)
        }

        return try next.respond(to: request)
    }

}
