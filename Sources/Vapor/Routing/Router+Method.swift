import Routing

/// Capable of registering async routes.
extension Router {
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on<RE: ResponseEncodable>(
        _ method: HTTPMethod,
        to path: [PathComponent],
        use closure: @escaping RouteResponder<RE>.Closure
    ) -> Route<Responder> {
        let responder = RouteResponder(closure: closure)
        let route = Route<Responder>(
            path: [.constants([.bytes(method.bytes)])] + path,
            output: responder
        )
        self.register(route: route)
        return route
    }
}


extension Router {
    /// Creates a `Route` at the provided path using the `GET` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func get<RE: ResponseEncodable>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<RE>.Closure
    ) -> Route<Responder> {
        return self.on(.get, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `PUT` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func put<RE: ResponseEncodable>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<RE>.Closure
    ) -> Route<Responder> {
        return self.on(.put, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `POST` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func post<RE: ResponseEncodable>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<RE>.Closure
    ) -> Route<Responder> {
        return self.on(.post, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `DELETE` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func delete<RE: ResponseEncodable>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<RE>.Closure
    ) -> Route<Responder> {
        return self.on(.delete, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `PATCH` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func patch<RE: ResponseEncodable>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<RE>.Closure
    ) -> Route<Responder> {
        return self.on(.patch, to: path, use: closure)
    }
}

