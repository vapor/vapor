public final class Routes: RoutesBuilder {
    public var routes: [Route]
    public var eventLoop: EventLoop
    
    public init(eventLoop: EventLoop) {
        self.routes = []
        self.eventLoop = eventLoop
    }
    
    public func add(_ route: Route) {
        self.routes.append(route)
    }
}

public protocol RoutesBuilder {
    var eventLoop: EventLoop { get }
    func add(_ route: Route)
}

extension RoutesBuilder {
    // MARK: Path
    
    /// Creates a new `Router` that will automatically prepend the supplied path components.
    ///
    ///     let users = router.grouped("user")
    ///     // Adding "user/auth/" route to router.
    ///     users.get("auth") { ... }
    ///     // adding "user/profile/" route to router
    ///     users.get("profile") { ... }
    ///
    /// - parameters:
    ///     - path: Group path components separated by commas.
    /// - returns: Newly created `Router` wrapped in the path.
    public func grouped(_ path: PathComponent...) -> RoutesBuilder {
        return HTTPRoutesGroup(root: self, path: path)
    }
    
    /// Creates a new `Router` that will automatically prepend the supplied path components.
    ///
    ///     router.group("user") { users in
    ///         // Adding "user/auth/" route to router.
    ///         users.get("auth") { ... }
    ///         // adding "user/profile/" route to router
    ///         users.get("profile") { ... }
    ///     }
    ///
    /// - parameters:
    ///     - path: Group path components separated by commas.
    ///     - configure: Closure to configure the newly created `Router`.
    public func group(_ path: PathComponent..., configure: (RoutesBuilder) -> ()) {
        configure(HTTPRoutesGroup(root: self, path: path))
    }
}

/// Groups routes
private final class HTTPRoutesGroup: RoutesBuilder {
    /// Router to cascade to.
    let root: RoutesBuilder
    
    /// Additional components.
    let path: [PathComponent]
    
    /// See `HTTPRoutesBuilder`.
    var eventLoop: EventLoop {
        return self.root.eventLoop
    }
    
    /// Creates a new `PathGroup`.
    init(root: RoutesBuilder, path: [PathComponent]) {
        self.root = root
        self.path = path
    }
    
    /// See `HTTPRoutesBuilder`.
    func add(_ route: Route) {
        route.path = self.path + route.path
        self.root.add(route)
    }
}


extension RoutesBuilder {
    @discardableResult
    public func get<Response>(_ path: PathComponent..., use closure: @escaping (RequestContext) throws -> Response) -> Route
        where Response: ResponseEncodable
    {
        return self._on(.GET, at: path, use: closure)
    }
    
    @discardableResult
    public func post<Response>(_ path: PathComponent..., use closure: @escaping (RequestContext) throws -> Response) -> Route
        where Response: ResponseEncodable
    {
        return self._on(.POST, at: path, use: closure)
    }
    
    @discardableResult
    public func webSocket(_ path: PathComponent..., onUpgrade: @escaping (RequestContext, WebSocket) -> ()) -> Route {
        return self._on(.GET, at: path) { req -> HTTPResponse in
            return try .webSocketUpgrade(for: req.http) { ws in
                onUpgrade(req, ws)
            }
        }
    }
    
    private func _on<Response>(
        _ method: HTTPMethod,
        at path: [PathComponent],
        use closure: @escaping (RequestContext) throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        let responder = BasicResponder(eventLoop: self.eventLoop) { req, eventLoop in
            return try closure(req).encode(for: req)
        }
        let route = Route(method: method, path: path, responder: responder)
        self.add(route)
        return route
    }
}

public final class Route {
    public var method: HTTPMethod
    public var path: [PathComponent]
    public var responder: Responder
    public var userInfo: [AnyHashable: Any]
    
    public init(method: HTTPMethod, path: [PathComponent], responder: Responder) {
        self.method = method
        self.path = path
        self.responder = responder
        self.userInfo = [:]
    }
}
