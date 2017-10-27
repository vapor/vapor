import Async
import HTTP

/// Capable of registering async routes.
extension Router {
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on<F: FutureType>(
        _ method: Method,
        to path: [PathComponent],
        use closure: @escaping BasicResponder<F>.Closure
        ) -> Route where F.Expectation: ResponseRepresentable {
        let responder = BasicResponder(closure: closure)
        let route = Route(method: method, path: path, responder: responder)
        self.register(route: route)
        
        return route
    }
}

/// A basic, closure-based responder.
public struct BasicResponder<F: FutureType>: Responder where F.Expectation: ResponseRepresentable {
    /// Responder closure
    public typealias Closure = (Request) throws -> F

    /// The stored responder closure.
    public let closure: Closure

    /// Create a new basic responder.
    public init(closure: @escaping Closure) {
        self.closure = closure
    }

    /// See: HTTP.Responder.respond
    public func respond(to req: Request) throws -> Future<Response> {
        return try closure(req).map { rep in
            return try rep.makeResponse(for: req)
        }
    }
}
