extension Router {
    // MARK: Content

    /// Creates a `Route` that automatically decodes `Content` at the provided path using the `POST` method.
    ///
    ///     router.post(User.self, at: "users") { req, user in
    ///         print(user) // User
    ///         // create user and return response...
    ///     }
    ///
    /// The above route closure would automatically decode a `User` to requests to `POST /users`.
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - content: `Content` type to automatically decode.
    ///     - path: Variadic `PathComponentsRepresentable` items.
    ///     - closure: Creates a `Response` for the incoming `Request`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func post<C, T>(_ content: C.Type, at path: PathComponentsRepresentable..., use closure: @escaping (Request, C) throws -> T) -> Route<Responder>
        where C: RequestDecodable, T: ResponseEncodable
    {
        return _on(.POST, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` that automatically decodes `Content` at the provided path using the `PATCH` method.
    ///
    ///     router.patch(User.self, at: "users", Int.parameter) { req, user in
    ///         let id = try req.parameters.next(Int.self)
    ///         print(id) // Int
    ///         print(user) // User
    ///         // update user and return response...
    ///     }
    ///
    /// The above route closure would automatically decode a `User` to requests to `PATCH /users/:id`.
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - content: `Content` type to automatically decode.
    ///     - path: Variadic `PathComponentsRepresentable` items.
    ///     - closure: Creates a `Response` for the incoming `Request`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func patch<C, T>(_ content: C.Type, at path: PathComponentsRepresentable..., use closure: @escaping (Request, C) throws -> T) -> Route<Responder>
        where C: RequestDecodable, T: ResponseEncodable
    {
        return _on(.PATCH, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` that automatically decodes `Content` at the provided path using the `PUT` method.
    ///
    ///     router.put(User.self, at: "users", Int.parameter) { req, user in
    ///         let id = try req.parameters.next(Int.self)
    ///         print(id) // Int
    ///         print(user) // User
    ///         // update user and return response...
    ///     }
    ///
    /// The above route closure would automatically decode a `User` to requests to `PUT /users/:id`.
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - content: `Content` type to automatically decode.
    ///     - path: Variadic `PathComponentsRepresentable` items.
    ///     - closure: Creates a `Response` for the incoming `Request`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func put<C, T>(_ content: C.Type, at path: PathComponentsRepresentable..., use closure: @escaping (Request, C) throws -> T) -> Route<Responder>
        where C: RequestDecodable, T: ResponseEncodable
    {
        return _on(.PUT, at: path.convertToPathComponents(), use: closure)
    }

    /// Creates a `Route` that automatically decodes `Content` at the provided path using an HTTP method.
    ///
    ///     router.on(.PUT, User.self, at: "users", Int.parameter) { req, user in
    ///         let id = try req.parameters.next(Int.self)
    ///         print(id) // Int
    ///         print(user) // User
    ///         // update user and return response...
    ///     }
    ///
    /// The above route closure would automatically decode a `User` to requests to `PUT /users/:id`.
    ///
    /// See `ParametersContainer` for more information on using dynamic parameters.
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to accept.
    ///     - content: `Content` type to automatically decode.
    ///     - path: Array of `PathComponent`s to define path.
    ///     - closure: Converts `Request` to a `Response`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func on<C, T>(_ method: HTTPMethod, _ content: C.Type, at path: PathComponentsRepresentable..., use closure: @escaping (Request, C) throws -> T) -> Route<Responder>
        where C: RequestDecodable, T: ResponseEncodable
    {
        return _on(method, at: path.convertToPathComponents(), use: closure)
    }

    /// Registers a route handler that automatically decodes content at the supplied path.
    ///
    /// Use the HTTP prefixed methods instead of this method. See `get(...)`, `post(...)`, etc.
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to accept.
    ///     - path: Array of `PathComponent`s to define path.
    ///     - closure: Converts `Request` to a `Response`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    private func _on<C, T>(_ method: HTTPMethod, at path: [PathComponent], use closure: @escaping (Request, C) throws -> T) -> Route<Responder>
        where C: RequestDecodable, T: ResponseEncodable
    {
        let responder = BasicResponder { req in
            return try C.decode(from: req).flatMap { content in
                let encodable = try closure(req, content)
                return try encodable.encode(for: req)
            }
        }
        let route = Route<Responder>(path: [.constant(method.string)] + path, output: responder)
        register(route: route)
        return route
    }
}
