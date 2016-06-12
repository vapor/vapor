class MultipartMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        
        if 
            case .buffer(let data) = request.body,
            let contentType = request.contentType
            where contentType.contains("multipart/form-data")
        {
            var request = request
            do {
                let boundary = try Multipart.parseBoundary(contentType: contentType)
                request.multipart = Multipart.parse(data, boundary: boundary)
            } catch {
                Log.warning("Could not parse MultiPart: \(error)")
            }
        }

        return try next.respond(to: request)
    }
}
