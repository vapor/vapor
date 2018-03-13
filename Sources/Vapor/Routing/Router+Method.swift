import Routing

/// Capable of registering async routes.
extension Router {
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on(
        _ method: HTTPMethod,
        at path: [DynamicPathComponent],
        use closure: @escaping RouteResponder.Closure
    ) -> Route<Responder> {
        let responder = RouteResponder(closure: closure)
        let route = Route<Responder>(
            path: [.constant(method.pathComponent)] + path,
            output: responder
        )
        self.register(route: route)
        return route
    }
    
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on<C>(
        _ method: HTTPMethod,
        at path: [DynamicPathComponent],
        use closure: @escaping RequestDecodableResponder<C>.Closure
    ) -> Route<Responder> where C: RequestDecodable {
        let responder = RequestDecodableResponder(closure: closure)
        let route = Route<Responder>(
            path: [.constant(method.pathComponent)] + path,
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
    public func get(
        _ path: DynamicPathComponentRepresentable...,
        use closure: @escaping RouteResponder.Closure
    ) -> Route<Responder> {
        return self.on(.GET, at: path.makeDynamicPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `PUT` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func put(
        _ path: DynamicPathComponentRepresentable...,
        use closure: @escaping RouteResponder.Closure
    ) -> Route<Responder> {
        return self.on(.PUT, at: path.makeDynamicPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `POST` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func post(
        _ path: DynamicPathComponentRepresentable...,
        use closure: @escaping RouteResponder.Closure
    ) -> Route<Responder> {
        return self.on(.POST, at: path.makeDynamicPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `DELETE` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func delete(
        _ path: DynamicPathComponentRepresentable...,
        use closure: @escaping RouteResponder.Closure
    ) -> Route<Responder> {
        return self.on(.DELETE, at: path.makeDynamicPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `PATCH` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func patch(
        _ path: DynamicPathComponentRepresentable...,
        use closure: @escaping RouteResponder.Closure
    ) -> Route<Responder> {
        return self.on(.PATCH, at: path.makeDynamicPathComponents(), use: closure)
    }
}

extension Router {
    /// Creates a `Route` at the provided path using the `PUT` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func put<C>(
        _ content: C.Type,
        at path: DynamicPathComponentRepresentable...,
        use closure: @escaping RequestDecodableResponder<C>.Closure
    ) -> Route<Responder> where C: RequestDecodable {
        return self.on(.PUT, at: path.makeDynamicPathComponents(), use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `POST` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func post<C>(
        _ content: C.Type,
        at path: DynamicPathComponentRepresentable...,
        use closure: @escaping RequestDecodableResponder<C>.Closure
    ) -> Route<Responder> where C: RequestDecodable {
        return self.on(.POST, at: path.makeDynamicPathComponents(), use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `PATCH` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func patch<C>(
        _ content: C.Type,
        at path: DynamicPathComponentRepresentable...,
        use closure: @escaping RequestDecodableResponder<C>.Closure
    ) -> Route<Responder> where C: RequestDecodable {
        return self.on(.PATCH, at: path.makeDynamicPathComponents(), use: closure)
    }
}
