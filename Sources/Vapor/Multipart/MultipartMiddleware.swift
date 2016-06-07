class MultipartMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        var request = request

        if let contentType = request.headers["content-type"] where contentType.range(of: "multipart/form-data") != nil {
            do {
                let data = try request.body.becomeBuffer()
                let boundary = try Multipart.parseBoundary(contentType: contentType)
                request.multipart = Multipart.parseMultipartForm(data, boundary: boundary)
            } catch {
                Log.warning("Could not parse MultiPart: \(error)")
            }
        }

        return try next.respond(to: request)
    }
}
