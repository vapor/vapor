class MultipartMiddleware: Middleware {
    func respond(to request: HTTP.Request, chainingTo next: HTTP.Responder) throws -> HTTP.Response {
        // mutable -- MUST be declared at top of function
        var request = request
        
        if
            case .data(let data) = request.body,
            let contentType = request.contentType
            where contentType.contains("multipart/form-data")
        {
            do {
                let boundary = try Multipart.parseBoundary(contentType: contentType)
                request.multipart = Multipart.parse(Data(data), boundary: boundary)
            } catch {
                Log.warning("Could not parse MultiPart: \(error)")
            }
        }

        return try next.respond(to: request)
    }
}
