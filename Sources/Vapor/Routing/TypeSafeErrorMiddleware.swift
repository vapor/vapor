import TypeSafeRouting
import HTTP

public final class TypeSafeErrorMiddleware: Middleware {
    public init() { }

    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        do {
            return try next.respond(to: request)
        } catch TypeSafeRoutingError.invalidParameterType(_) {
            throw Abort.notFound
        } catch TypeSafeRoutingError.missingParameter {
            throw Abort.notFound
        }
    }
}
