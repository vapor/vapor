public final class HTTPRoutes: HTTPRoutesBuilder {
    public var routes: [HTTPRoute]
    public var eventLoop: EventLoop
    
    public init(eventLoop: EventLoop) {
        self.routes = []
        self.eventLoop = eventLoop
    }
    
    public func add(_ route: HTTPRoute) {
        self.routes.append(route)
    }
}

public protocol HTTPRoutesBuilder {
    var eventLoop: EventLoop { get }
    func add(_ route: HTTPRoute)
}

extension HTTPRoutesBuilder {
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
    public func grouped(_ path: PathComponent...) -> HTTPRoutesBuilder {
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
    public func group(_ path: PathComponent..., configure: (HTTPRoutesBuilder) -> ()) {
        configure(HTTPRoutesGroup(root: self, path: path))
    }
}

/// Groups routes
private final class HTTPRoutesGroup: HTTPRoutesBuilder {
    /// Router to cascade to.
    let root: HTTPRoutesBuilder
    
    /// Additional components.
    let path: [PathComponent]
    
    /// See `HTTPRoutesBuilder`.
    var eventLoop: EventLoop {
        return self.root.eventLoop
    }
    
    /// Creates a new `PathGroup`.
    init(root: HTTPRoutesBuilder, path: [PathComponent]) {
        self.root = root
        self.path = path
    }
    
    /// See `HTTPRoutesBuilder`.
    func add(_ route: HTTPRoute) {
        route.path = self.path + route.path
        self.root.add(route)
    }
}


extension HTTPRoutesBuilder {
    @discardableResult
    public func get<Response>(_ path: PathComponent..., use closure: @escaping (HTTPRequest) throws -> Response) -> HTTPRoute
        where Response: HTTPResponseEncodable
    {
        return self._on(.GET, at: path, use: closure)
    }
    
    @discardableResult
    public func get<Response>(_ path: PathComponent..., use closure: @escaping (HTTPRequest) throws -> EventLoopFuture<Response>) -> HTTPRoute
        where Response: HTTPResponseEncodable
    {
        return self._on(.GET, at: path, use: closure)
    }
    
    @discardableResult
    public func post<Response>(_ path: PathComponent..., use closure: @escaping (HTTPRequest) throws -> Response) -> HTTPRoute
        where Response: HTTPResponseEncodable
    {
        return self._on(.POST, at: path, use: closure)
    }
    
    @discardableResult
    public func post<Response>(_ path: PathComponent..., use closure: @escaping (HTTPRequest) throws -> EventLoopFuture<Response>) -> HTTPRoute
        where Response: HTTPResponseEncodable
    {
        return self._on(.POST, at: path, use: closure)
    }
    
    // Sync
    private func _on<Response>(
        _ method: HTTPMethod,
        at path: [PathComponent],
        use closure: @escaping (HTTPRequest) throws -> Response
    ) -> HTTPRoute
        where Response: HTTPResponseEncodable
    {
        let responder = BasicResponder(eventLoop: self.eventLoop) { req, eventLoop in
            let res = try closure(req.http).encode(for: req.http)
            return eventLoop.makeSucceededFuture(result: res)
        }
        let route = HTTPRoute(method: method, path: path, responder: responder)
        self.add(route)
        return route
    }
    
    // Async
    private func _on<Response>(
        _ method: HTTPMethod,
        at path: [PathComponent],
        use closure: @escaping (HTTPRequest) throws -> EventLoopFuture<Response>
    ) -> HTTPRoute
        where Response: HTTPResponseEncodable
    {
        #warning("TODO: combine sync + async route closure returns by conforming Future to HTTPResponseEncodable")
        let responder = BasicResponder(eventLoop: self.eventLoop) { req, eventLoop in
            return try closure(req.http).thenThrowing { try $0.encode(for: req.http) }
        }
        let route = HTTPRoute(method: method, path: path, responder: responder)
        self.add(route)
        return route
    }
}

public final class HTTPRoute {
    public var method: HTTPMethod
    public var path: [PathComponent]
    public var responder: HTTPResponder
    public var userInfo: [AnyHashable: Any]
    
    public init(method: HTTPMethod, path: [PathComponent], responder: HTTPResponder) {
        self.method = method
        self.path = path
        self.responder = responder
        self.userInfo = [:]
    }
}
