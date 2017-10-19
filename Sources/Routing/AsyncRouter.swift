import Async
import HTTP

/// Capable of register async routes.
///
/// http://localhost:8000/routing/async/
public protocol AsyncRouter: Router { }

extension AsyncRouter {
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on<F: FutureType>(
        _ method: Method,
        to path: [PathComponent],
        use closure: @escaping BasicAsyncResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        let responder = BasicAsyncResponder(closure: closure)
        let route = Route(method: method, path: path, responder: responder)
        self.register(route: route)
        
        return route
    }
}

/// A basic, closure-based responder.
public struct BasicAsyncResponder<F: FutureType>: Responder where F.Expectation: ResponseRepresentable {
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

