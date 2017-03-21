import HTTP

/// Middleware that supports mapping a specific HTTP method to another.
/// - example: If `.put` is mapped to `.patch`, all **PUT** requests will be responded to as if they were **PATCH** requests.
public final class MethodMapMiddleware: Middleware {
    private var methodMap: [Method: Method]

    public init(_ map: [Method: Method]) {
        self.methodMap = map
    }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard let newMethod = methodMap[request.method] else { return try next.respond(to: request) }

        request.method = newMethod

        return try next.respond(to: request)
    }
}
