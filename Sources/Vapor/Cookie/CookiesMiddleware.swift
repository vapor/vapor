class CookiesMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        var request = request

        if let cookie = request.headers["Cookie"] {
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
