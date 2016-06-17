class JSONMiddleware: Middleware {
    func respond(to request: HTTP.Request, chainingTo next: HTTP.Responder) throws -> HTTP.Response {
        if
            case .data(let data) = request.body,
            let contentType = request.contentType
            where contentType.contains("application/json")
        {
            do {
                request.json = try JSON.deserializer(data: data)
            } catch {
                Log.warning("Could not parse JSON: \(error)")
            }
        }

        // Serialize Response JSON
        let response = try next.respond(to: request)

        if let json = response.json {
            response.headers["Content-Type"] = "application/json"
            response.body = HTTP.Body(json)
        }

        return response
    }
}
