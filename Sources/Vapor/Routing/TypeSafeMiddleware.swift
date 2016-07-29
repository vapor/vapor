import TypeSafeRouting
import Engine

public final class TypeSafeMiddleware: Middleware {
    public init() { }

    public func respond(to request: HTTPRequest, chainingTo next: HTTPResponder) throws -> HTTPResponse {
        do {
            return try next.respond(to: request)
        } catch TypeSafeRoutingError.invalidParameterType(_) {
            throw Abort.notFound
        } catch TypeSafeRoutingError.missingParameter {
            throw Abort.notFound
        }
    }
}
