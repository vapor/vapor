public protocol Middleware: Service {
    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response>
}

/// A wrapper that applies the supplied middleware to a responder.
///
/// Note: internal since it is exposed through `makeResponder` extensions.
public final class MiddlewareResponder: Responder, Service {
    /// The middleware to apply.
    let middleware: Middleware

    /// The actual responder.
    let chained: Responder

    /// Creates a new middleware responder.
    init(middleware: Middleware, chained: Responder) {
        self.middleware = middleware
        self.chained = chained
    }

    /// Responder conformance.
    public func respond(to req: Request) throws -> Future<Response> {
        return try middleware.respond(to: req, chainingTo: chained)
    }
}


// MARK: Convenience

extension Middleware {
    /// Converts a middleware into a responder by chaining it to an actual responder.
    public func makeResponder(chainedTo responder: Responder) -> MiddlewareResponder {
        return MiddlewareResponder(middleware: self, chained: responder)
    }
}

/// Extension on [Middleware]
extension Array where Element == Middleware {
    /// Converts an array of middleware into a responder by
    /// chaining them to an actual responder.
    public func makeResponder(chainedto responder: Responder) -> MiddlewareResponder {
        var responder = responder
        for middleware in self {
            responder = middleware.makeResponder(chainedTo: responder)
        }
        return responder as! MiddlewareResponder
    }
}

/// Extension on [ConcreteMiddleware]
extension Array where Element: Middleware {
    /// Converts an array of middleware into a responder by
    /// chaining them to an actual responder.
    public func makeResponder(chainedto responder: Responder) -> MiddlewareResponder {
        var responder = responder
        for middleware in self {
            responder = middleware.makeResponder(chainedTo: responder)
        }
        return responder as! MiddlewareResponder
    }
}
