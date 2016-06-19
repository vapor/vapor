class CookiesMiddleware: Middleware {
    func respond(to request: HTTPRequest, chainingTo next: HTTPResponder) throws -> HTTPResponse {
        // mutable -- MUST be declared at top of function
//        var request = request

        // TODO:
//        if let cookie = request.headers["Cookie"] {
//            request.cookies = Cookies(cookie.data)
//        }

        // Serialize cookies to Response headers
        let response = try next.respond(to: request)

        // TODO:
//        let cookies = response.cookies.serialize()
//        if cookies.count > 0 {
//            response.headers["Set-Cookie"] = cookies.string
//        }

        return response
    }
}
