class FormURLEncodedMiddleware: Middleware {
    func respond(to request: HTTP.Request, chainingTo next: HTTP.Responder) throws -> HTTP.Response {
        // mutable -- MUST be declared at top of function
        var request = request

        if
            case .data(let data) = request.body,
            let contentType = request.contentType
            where contentType.contains("application/x-www-form-urlencoded")
        {
            request.formURLEncoded = StructuredData(formURLEncoded: Data(data))
        }

        return try next.respond(to: request)
    }
}
