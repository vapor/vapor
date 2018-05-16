/// Capable of registering async routes.
extension Router {
    // MARK: Method

    /// Creates a `Route` at the provided path using the `GET` method.
    ///
    ///     router.get("hello", "world") { req in
    ///         return "Hello, world!"
    ///     }
    ///
    /// The above route closure would return `"Hello, world"` to requests to `GET /hello/world`.
    ///
    /// You can use anything `PathComponentsRepresentable` to create the path, including dynamic parameters.
    ///
    ///     router.get("users", Int.parameter) { req in
    ///         let id = try req.parameters.next(Int.self)
    ///         return "User #\(id)"
    ///     }
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - path: Variadic `PathComponentsRepresentable` items.
    ///     - closure: Creates a `Response` for the incoming `Request`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func get<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return _on(.GET, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `POST` method.
    ///
    ///     router.post("hello", "world") { req in
    ///         return "Hello, world!"
    ///     }
    ///
    /// The above route closure would return `"Hello, world"` to requests to `POST /hello/world`.
    ///
    /// You can use anything `PathComponentsRepresentable` to create the path, including dynamic parameters.
    ///
    ///     router.post("users", Int.parameter) { req in
    ///         let id = try req.parameters.next(Int.self)
    ///         return "User #\(id)"
    ///     }
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - path: Variadic `PathComponentsRepresentable` items.
    ///     - closure: Creates a `Response` for the incoming `Request`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func post<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return _on(.POST, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `PATCH` method.
    ///
    ///     router.patch("hello", "world") { req in
    ///         return "Hello, world!"
    ///     }
    ///
    /// The above route closure would return `"Hello, world"` to requests to `PATCH /hello/world`.
    ///
    /// You can use anything `PathComponentsRepresentable` to create the path, including dynamic parameters.
    ///
    ///     router.patch("users", Int.parameter) { req in
    ///         let id = try req.parameters.next(Int.self)
    ///         return "User #\(id)"
    ///     }
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - path: Variadic `PathComponentsRepresentable` items.
    ///     - closure: Creates a `Response` for the incoming `Request`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func patch<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return _on(.PATCH, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `PUT` method.
    ///
    ///     router.put("hello", "world") { req in
    ///         return "Hello, world!"
    ///     }
    ///
    /// The above route closure would return `"Hello, world"` to requests to `PUT /hello/world`.
    ///
    /// You can use anything `PathComponentsRepresentable` to create the path, including dynamic parameters.
    ///
    ///     router.put("users", Int.parameter) { req in
    ///         let id = try req.parameters.next(Int.self)
    ///         return "User #\(id)"
    ///     }
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - path: Variadic `PathComponentsRepresentable` items.
    ///     - closure: Creates a `Response` for the incoming `Request`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func put<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return _on(.PUT, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using the `DELETE` method.
    ///
    ///     router.delete("hello", "world") { req in
    ///         return "Hello, world!"
    ///     }
    ///
    /// The above route closure would return `"Hello, world"` to requests to `DELETE /hello/world`.
    ///
    /// You can use anything `PathComponentsRepresentable` to create the path, including dynamic parameters.
    ///
    ///     router.delete("users", Int.parameter) { req in
    ///         let id = try req.parameters.next(Int.self)
    ///         return "User #\(id)"
    ///     }
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - path: Variadic `PathComponentsRepresentable` items.
    ///     - closure: Creates a `Response` for the incoming `Request`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func delete<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return _on(.DELETE, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using an HTTP method.
    ///
    ///     router.on(.GET, at: "hello", "world") { req in
    ///         return "Hello, world!"
    ///     }
    ///
    /// The above route closure would return `"Hello, world"` to requests to `GET /hello/world`.
    ///
    /// You can use anything `PathComponentsRepresentable` to create the path, including dynamic parameters.
    ///
    ///     router.on(.GET, at: "users", Int.parameter) { req in
    ///         let id = try req.parameters.next(Int.self)
    ///         return "User #\(id)"
    ///     }
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to accept.
    ///     - path: Variadic `PathComponentsRepresentable` items.
    ///     - closure: Creates a `Response` for the incoming `Request`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func on<T>(_ method: HTTPMethod, at path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return _on(method, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` at the provided path using an HTTP method.
    ///
    ///     router.on(.GET, at: ["hello", "world"]) { req in
    ///         return "Hello, world!"
    ///     }
    ///
    /// The above route closure would return `"Hello, world"` to requests to `GET /hello/world`.
    ///
    /// You can use anything `PathComponentsRepresentable` to create the path, including dynamic parameters.
    ///
    ///     router.on(.GET, at: ["users", Int.parameter]) { req in
    ///         let id = try req.parameters.next(Int.self)
    ///         return "User #\(id)"
    ///     }
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to accept.
    ///     - path: Variadic `PathComponentsRepresentable` items.
    ///     - closure: Creates a `Response` for the incoming `Request`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func on<T>(_ method: HTTPMethod, at path: [PathComponentsRepresentable], use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return _on(method, at: path.convertToPathComponents(), use: closure)
    }
    
    /// Registers a route handler at the supplied path.
    ///
    /// Use the HTTP prefixed methods instead of this method. See `get(...)`, `post(...)`, etc.
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to accept.
    ///     - path: Array of `PathComponent`s to define path.
    ///     - closure: Converts `Request` to a `Response`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    private func _on<T>(_ method: HTTPMethod, at path: [PathComponent], use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        let responder = BasicResponder { try closure($0).encode(for: $0) }
        let route = Route<Responder>(path: [.constant(method.string)] + path, output: responder)
        register(route: route)
        return route
    }
}
