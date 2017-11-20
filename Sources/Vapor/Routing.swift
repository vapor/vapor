import Async
import HTTP
import Routing

/// Capable of registering async routes.
extension Router {
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on<F: FutureType>(
        _ method: Method,
        to path: [PathComponent],
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseEncodable {
        let responder = RouteResponder(closure: closure)
        let route = Route(method: method, path: path, responder: responder)
        self.register(route: route)

        return route
    }
}

/// A basic, closure-based responder.
public struct RouteResponder<F: FutureType>: Responder
    where F.Expectation: ResponseEncodable
{
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
        return try closure(req).then { rep in
            var res = req.makeResponse()
            return try rep.encode(to: &res, for: req).map {
                return res
            }
        }
    }
}


/// Converts a router into a responder.
public struct RouterResponder: Responder {
    let router: Router
    
    /// Creates a new responder for a router
    public init(router: Router) {
        self.router = router
    }

    /// Responds to a request using the Router
    public func respond(to req: Request) throws -> Future<Response> {
        guard let responder = router.route(request: req) else {
            return Future(Response(status: .notFound))
        }

        return try responder.respond(to: req)
    }
}

extension Router {
    /// Creates a `Route` at the provided path using the `GET` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func get<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseEncodable {
        return self.on(.get, to: path, use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `PUT` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func put<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseEncodable {
        return self.on(.put, to: path, use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `POST` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func post<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseEncodable {
        return self.on(.post, to: path, use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `DELETE` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func delete<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseEncodable {
        return self.on(.delete, to: path, use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `PATCH` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func patch<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseEncodable {
        return self.on(.patch, to: path, use: closure)
    }
}
