/// `Middleware` is placed between the server and your router. It is capable of
/// mutating both incoming requests and outgoing responses. `Middleware` can choose
/// to pass requests on to the next `Middleware` in a chain, or they can short circuit and
/// return a custom `Response` if desired.
///
/// `MiddlewareConfig` is used to configure which `Middleware` are active for a given
/// service-container and in which order they should be run.
public protocol Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response>
}

extension Array where Element == Middleware {
    /// Wraps a `Responder` in an array of `Middleware` creating a new `Responder`.
    /// - note: The array of middleware must be `[Middleware]` not `[M] where M: Middleware`.
    public func makeResponder(chainedto responder: Responder) -> Responder {
        var responder = responder
        for middleware in self {
            responder = middleware.makeResponder(chainingTo: responder)
        }
        return responder
    }
}

public extension Middleware {
    /// Wraps a `Responder` in a single `Middleware` creating a new `Responder`.
    func makeResponder(chainingTo responder: Responder) -> Responder {
        return BasicResponder { try self.respond(to: $0, chainingTo: responder) }
    }
}
