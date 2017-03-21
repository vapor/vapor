import HTTP

/// Middleware that implements the HEAD response specification.
/// - seealso: [Hypertext Transfer Protocol -- HTTP/1.1](https://tools.ietf.org/html/rfc2616#section-9.4)
public final class HeadMiddleware: Middleware {
    /// Changes the request's HTTP method to `.get` and continues the response chain.
    /// The response's body is removed before returning the response.
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard request.method == .head else { return try next.respond(to: request) }

        // The HEAD method is identical to GET.
        request.method = .get
        let response = try next.respond(to: request)

        // The server MUST NOT return a message-body in the response for HEAD.
        response.body = .data([])

        return response
    }
}
