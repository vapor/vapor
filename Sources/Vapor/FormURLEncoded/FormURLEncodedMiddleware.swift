class FormURLEncodedMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        
        if 
            case .buffer(let data) = request.body,
            let contentType = request.contentType
            where contentType.contains("application/x-www-form-urlencoded") 
        {
            var request = request
            request.formURLEncoded = FormURLEncoded.parse(data)
        }

        return try next.respond(to: request)
    }
}
