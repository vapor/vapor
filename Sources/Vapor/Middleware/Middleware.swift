public protocol Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response>
}


/// Wrapper to create Middleware from function
public final class MiddlewareFunction: Middleware {
    /// Closure of `Request` than return `Response` wrapped in `Future` using `Responder`
    public typealias Respond = (Request, Responder) throws -> Future<Response>
    
    private let respond: Respond
    
    init(_ function: @escaping Respond) {
        self.respond = function
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        return try self.respond(request,next)
    }
    
}

/// A wrapper that applies the supplied middleware to a responder.
///
/// Note: internal since it is exposed through `makeResponder` extensions.
internal final class MiddlewareResponder: Responder {
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
    func respond(to req: Request) throws -> Future<Response> {
        return try middleware.respond(to: req, chainingTo: chained)
    }
}


// MARK: Convenience

extension Middleware {
    /// Converts a middleware into a responder by chaining it to an actual responder.
    public func makeResponder(chainedTo responder: Responder) -> Responder {
        return MiddlewareResponder(middleware: self, chained: responder)
    }
}

/// Extension on [Middleware]
extension Array where Element == Middleware {
    /// Converts an array of middleware into a responder by
    /// chaining them to an actual responder.
    public func makeResponder(chainedto responder: Responder) -> Responder {
        var responder = responder
        for middleware in self {
            responder = middleware.makeResponder(chainedTo: responder)
        }
        return responder
    }
}

/// Extension on [ConcreteMiddleware]
extension Array where Element: Middleware {
    /// Converts an array of middleware into a responder by
    /// chaining them to an actual responder.
    public func makeResponder(chainedto responder: Responder) -> Responder {
        var responder = responder
        for middleware in self {
            responder = middleware.makeResponder(chainedTo: responder)
        }
        return responder
    }
}
