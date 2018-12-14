/// `Middleware` is placed between the server and your router. It is capable of
/// mutating both incoming requests and outgoing responses. `Middleware` can choose
/// to pass requests on to the next `Middleware` in a chain, or they can short circuit and
/// return a custom `Response` if desired.
///
/// `MiddlewareConfig` is used to configure which `Middleware` are active for a given
/// service-container and in which order they should be run.
public protocol HTTPMiddleware {
    /// Called with each `Request` that passes through this middleware.
    /// - parameters:
    ///     - request: The incoming `Request`.
    ///     - next: Next `Responder` in the chain, potentially another middleware or the main router.
    /// - returns: An asynchronous `Response`.
    func respond(to req: HTTPRequest, chainingTo next: HTTPResponder) -> EventLoopFuture<HTTPResponse>
}

extension Array where Element == HTTPMiddleware {
    /// Wraps a `Responder` in an array of `Middleware` creating a new `Responder`.
    /// - note: The array of middleware must be `[Middleware]` not `[M] where M: Middleware`.
    public func makeResponder(chainingTo responder: HTTPResponder) -> HTTPResponder {
        var responder = responder
        for middleware in reversed() {
            responder = middleware.makeResponder(chainingTo: responder)
        }
        return responder
    }
}

public extension HTTPMiddleware {
    /// Wraps a `Responder` in a single `Middleware` creating a new `Responder`.
    func makeResponder(chainingTo responder: HTTPResponder) -> HTTPResponder {
        return BasicResponder { try self.respond(to: $0, chainingTo: responder) }
    }
}
