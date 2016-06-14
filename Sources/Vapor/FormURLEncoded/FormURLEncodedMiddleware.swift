class FormURLEncodedMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        // mutable -- MUST be declared at top of function
        var request = request

        if
            case .buffer(let data) = request.body,
            let contentType = request.contentType
            where contentType.contains("application/x-www-form-urlencoded")
        {
            request.formURLEncoded = StructuredData(formURLEncoded: data)
        }

        return try next.respond(to: request)
    }
}
