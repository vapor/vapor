import Routing

/// Capable of registering async routes.
extension Router {
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on<T>(
        _ method: HTTPMethod,
        to path: [PathComponent],
        use closure: @escaping RouteResponder<T>.Closure
    ) -> Route<Responder> where T: ResponseEncodable {
        let responder = RouteResponder(closure: closure)
        let route = Route<Responder>(
            path: [.constants([.bytes(method.bytes)])] + path,
            output: responder
        )
        self.register(route: route)
        return route
    }
}

extension Future: ResponseEncodable where T: ResponseEncodable {
    /// See ResponseEncodable.encode
    public func encode(for req: Request) throws -> Future<Response> {
        return flatMap(to: Response.self) { exp in
            try exp.encode(for: req)
        }
    }


}

extension Router {
    /// Creates a `Route` at the provided path using the `GET` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func get<T>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<T>.Closure
    ) -> Route<Responder> where T: ResponseEncodable {
        return self.on(.get, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `PUT` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func put<T>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<T>.Closure
    ) -> Route<Responder> where T: ResponseEncodable {
        return self.on(.put, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `POST` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func post<T>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<T>.Closure
    ) -> Route<Responder> where T: ResponseEncodable {
        return self.on(.post, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `DELETE` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func delete<T>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<T>.Closure
    ) -> Route<Responder> where T: ResponseEncodable {
        return self.on(.delete, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `PATCH` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func patch<T>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<T>.Closure
    ) -> Route<Responder> where T: ResponseEncodable {
        return self.on(.patch, to: path, use: closure)
    }
}

