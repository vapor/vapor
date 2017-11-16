import Async
import HTTP
import Routing

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
    /// Creates an Async `Route` at the provided path using the `GET` method.
    ///
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func get<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.get, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Async `Route` at the provided path using the `PUT` method.
    ///
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func put<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.put, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Async `Route` at the provided path using the `POST` method.
    ///
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func post<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.post, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Async `Route` at the provided path using the `DELETE` method.
    ///
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func delete<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.delete, to: path.makePathComponents(), use: closure)
    }
    
    /// Creates  Async `Route` at the provided path using the `PATCH` method.
    ///
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func patch<F: FutureType>(
        _ path: PathComponentRepresentable...,
        use closure: @escaping BasicResponder<F>.Closure
    ) -> Route where F.Expectation: ResponseRepresentable {
        return self.on(.patch, to: path.makePathComponents(), use: closure)
    }
}
