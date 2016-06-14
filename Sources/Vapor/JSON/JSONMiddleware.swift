class JSONMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        // mutable -- MUST be declared at top of function
        var request = request

        // Parse Request JSON
        if
            case .buffer(let data) = request.body,
            let contentType = request.contentType
            where contentType.contains("application/json")
        {
            do {
                request.json = try JSON(data)
            } catch {
                Log.warning("Could not parse JSON: \(error)")
            }
        }

        // Serialize Response JSON
        var response = try next.respond(to: request)

        if let json = response.json {
            response.headers["Content-Type"] = "application/json"
            let data = json.data
            response.headers["Content-Length"] = "\(data.bytes.count)"
            response.body = .buffer(data)
        }

        return response
    }
}
