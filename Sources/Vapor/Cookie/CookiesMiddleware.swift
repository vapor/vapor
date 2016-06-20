class CookiesMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        // mutable -- MUST be declared at top of function
        var request = request

        if let cookie = request.headers["Cookie"] {
            request.cookies = Cookies(cookie.data)
        }

        // Serialize cookies to Response headers
        var response = try next.respond(to: request)

        let cookies = response.cookies.serialize()
        if cookies.count > 0 {
            response.headers["Set-Cookie"] = cookies.string
        }

        return response
    }
}
