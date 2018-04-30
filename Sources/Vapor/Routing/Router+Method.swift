/// Capable of registering async routes.
extension Router {
    // MARK: HTTP

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
        return on(.GET, at: path.convertToPathComponents(), use: closure)
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
        return on(.POST, at: path.convertToPathComponents(), use: closure)
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
        return on(.PATCH, at: path.convertToPathComponents(), use: closure)
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
        return on(.PUT, at: path.convertToPathComponents(), use: closure)
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
    public func delete<T>(_ path: PathComponentsRepresentable..., use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        return on(.DELETE, at: path.convertToPathComponents(), use: closure)
    }

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
        return on(.POST, at: path.convertToPathComponents(), use: closure)
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
        return on(.PATCH, at: path.convertToPathComponents(), use: closure)
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
        return on(.PUT, at: path.convertToPathComponents(), use: closure)
    }

    // MARK: Custom

    /// Registers a route handler at the supplied path.
    ///
    /// Usually you will use the HTTP prefixed methods instead of this method. See `get(...)`, `post(...)`, etc.
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to accept.
    ///     - path: Array of `PathComponent`s to define path.
    ///     - closure: Converts `Request` to a `Response`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func on<T>(_ method: HTTPMethod, at path: [PathComponent], use closure: @escaping (Request) throws -> T) -> Route<Responder>
        where T: ResponseEncodable
    {
        let responder = BasicResponder { try closure($0).encode(for: $0) }
        let route = Route<Responder>(path: [.constant(method.string)] + path, output: responder)
        register(route: route)
        return route
    }

    /// Registers a route handler that automatically decodes content at the supplied path.
    ///
    /// Usually you will use the HTTP prefixed methods instead of this method. See `get(...)`, `post(...)`, etc.
    ///
    /// - parameters:
    ///     - method: `HTTPMethod` to accept.
    ///     - path: Array of `PathComponent`s to define path.
    ///     - closure: Converts `Request` to a `Response`.
    /// - returns: Discardable `Route` that was just created.
    @discardableResult
    public func on<C, T>(_ method: HTTPMethod, at path: [PathComponent], use closure: @escaping (Request, C) throws -> T) -> Route<Responder>
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
