class CookiesMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        if let cookie = request.headers["Cookie"] {
            var request = request
            request.cookies = Cookies.parse(header: cookie)
        }

        // Serialize cookies to Response headers
        var response = try next.respond(to: request)

        if let cookies = response.cookies.serialize() {
            response.headers["Set-Cookie"] = String(cookies)
        }

        return response
    }
}
