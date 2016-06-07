class FormURLEncodedMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        var request = request

        if request.headers["content-type"]?.range(of: "application/x-www-form-urlencoded") != nil {
            do {
                let data = try request.body.becomeBuffer()
                request.formURLEncoded = FormURLEncoded.parse(data)
            } catch {
                Log.warning("Could not parse Form-URLEncoded: \(error)")
            }

        }

        return try next.respond(to: request)
    }
}
