import HTTP

public final class MethodSwap: Middleware {
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard let method = request.data["_method"]?.string else {
            return try next.respond(to: request)
        }

        request.method = Method(method)
        return try next.respond(to: request)
    }
}
