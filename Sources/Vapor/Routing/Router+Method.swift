import Routing

/// Capable of registering async routes.
extension Router {
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on<F: FutureType>(
        _ method: HTTPMethod,
        to path: [PathComponent],
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        let responder = RouteResponder(closure: closure)
        let route = Route<Responder>(
            path: [.constants([method.data])] + path,
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
    public func get<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        return self.on(.get, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `PUT` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func put<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        return self.on(.put, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `POST` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func post<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        return self.on(.post, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `DELETE` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func delete<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        return self.on(.delete, to: path, use: closure)
    }

    /// Creates a `Route` at the provided path using the `PATCH` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func patch<F: FutureType>(
        _ path: PathComponent...,
        use closure: @escaping RouteResponder<F>.Closure
    ) -> Route<Responder> where F.Expectation: ResponseEncodable {
        return self.on(.patch, to: path, use: closure)
    }
}

