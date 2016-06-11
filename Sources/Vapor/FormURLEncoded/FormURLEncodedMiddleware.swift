class FormURLEncodedMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        
        if 
            case .buffer(let data) = request.body,
            let contentType = request.contentType
            where contentType.range(of: "application/x-www-form-urlencoded") != nil
        {
            var request = request
            request.formURLEncoded = StructuredData(formURLEncoded: data)
        }

        return try next.respond(to: request)
    }
}
