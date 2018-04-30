import Routing

/// Capable of registering async routes.
extension Router {
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on<T>(_ method: HTTPMethod, at path: [PathComponent], use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        let responder = RouteResponder(closure: closure)
        let route = Route<Responder>(path: [method.pathComponent] + path, output: responder)
        register(route: route)
        return route
    }
    
    /// Registers a route handler at the supplied path.
    @discardableResult
    public func on<C, T>(_ method: HTTPMethod, at path: [PathComponent], use closure: @escaping (Request, C) throws -> T) -> Route<Responder>
        where C: RequestDecodable, T: ResponseEncodable
    {
        let responder = RequestDecodableResponder(closure: closure)
        let route = Route<Responder>(path: [method.pathComponent] + path, output: responder)
        register(route: route)
        return route
    }
}

extension Future: ResponseEncodable where T: ResponseEncodable {
    /// See ResponseEncodable.encode
    public func encode(for req: Request) throws -> Future<Response> {
        return flatMap { exp in
            try exp.encode(for: req)
        }
    }
}

extension Router {
    /// Creates a `Route` at the provided path using the `GET` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func get<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return on(.GET, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `PUT` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func put<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return on(.PUT, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `POST` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func post<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return on(.POST, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `DELETE` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func delete<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return on(.DELETE, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `PATCH` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func patch<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return on(.PATCH, at: path.convertToPathComponents(), use: closure)
    }
}

extension Router {
    /// Creates a `Route` at the provided path using the `PUT` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func put<C, T>(
        _ content: C.Type,
        at path: PathComponentsRepresentable...,
        use closure: @escaping RequestDecodableResponder<C, T>.Closure
    ) -> Route<Responder> where C: RequestDecodable, T: ResponseEncodable {
        return self.on(.PUT, at: path.convertToPathComponents(), use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `POST` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func post<C, T>(
        _ content: C.Type,
        at path: PathComponentsRepresentable...,
        use closure: @escaping RequestDecodableResponder<C, T>.Closure
    ) -> Route<Responder> where C: RequestDecodable, T: ResponseEncodable {
        return self.on(.POST, at: path.convertToPathComponents(), use: closure)
    }
    
    /// Creates a `Route` at the provided path using the `PATCH` method.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/getting-started/routing/)
    @discardableResult
    public func patch<C, T>(
        _ content: C.Type,
        at path: PathComponentsRepresentable...,
        use closure: @escaping RequestDecodableResponder<C, T>.Closure
    ) -> Route<Responder> where C: RequestDecodable, T: ResponseEncodable {
        return self.on(.PATCH, at: path.convertToPathComponents(), use: closure)
    }
}
