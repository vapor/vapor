import HTTP

public final class HeadMiddleware: Middleware {
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard request.method == .head else { return try next.respond(to: request) }
        /// The HEAD method is identical to GET.
        ///
        /// https://tools.ietf.org/html/rfc2616#section-9.4
        request.method = .get
        let response = try next.respond(to: request)

        /// The server MUST NOT return a message-body in the response for HEAD.
        ///
        /// https://tools.ietf.org/html/rfc2616#section-9.4
        response.body = .data([])
        return response
    }
}
