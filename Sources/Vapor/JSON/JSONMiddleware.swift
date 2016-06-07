class JSONMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        var request = request
        if request.headers["content-type"]?.range(of: "application/json") != nil {
            do {
                let data = try request.body.becomeBuffer()
                request.json = try JSON(data)
            } catch {
                Log.warning("Could not parse JSON: \(error)")
            }
        }

        var response = try next.respond(to: request)

        if let json = response.json {
            response.headers["content-type"] = "application/json"
            response.body = .buffer(json.data)
        }

        return response
    }
}
