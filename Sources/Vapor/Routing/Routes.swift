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

public enum HTTPBodyStreamStrategy {
    public static var collect: HTTPBodyStreamStrategy {
        return .collect(maxSize: 2 << 14)
    }
    case allow
    case collect(maxSize: Int)
}

extension RoutesBuilder {
    @discardableResult
    public func get<Response>(
        _ path: PathComponent...,
        use closure: @escaping (HTTPRequest, Context) throws -> Response
    ) -> Route
        where Response: ResponseEncodable
    {
        return self._on(.GET, to: path, use: closure)
    }
    
    @discardableResult
    public func get<Request, Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request, Context) throws -> Response
    ) -> Route
        where Request: RequestDecodable, Response: ResponseEncodable
    {
        return self._on(.GET, to: path, use: closure)
    }
    
    @discardableResult
    public func post<Request, Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request, Context) throws -> Response
    ) -> Route
        where Request: RequestDecodable, Response: ResponseEncodable
    {
        return self._on(.POST, to: path, use: closure)
    }
    
    #warning("TODO: allow Request here")
    @discardableResult
    public func webSocket(
        _ path: PathComponent...,
        onUpgrade: @escaping (HTTPRequest, Context, WebSocket) -> ()
    ) -> Route {
        return self._on(.GET, to: path) { (req: HTTPRequest, ctx: Context) -> EventLoopFuture<HTTPResponse> in
            return req.makeWebSocketUpgradeResponse(on: ctx.channel, onUpgrade: { ws in
                onUpgrade(req, ctx, ws)
            })
        }
    }
    
    @discardableResult
    public func on<Request, Response>(
        _ method: HTTPMethod,
        to path: PathComponent...,
        bodyStream: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (Request, Context) throws -> Response
    ) -> Route
        where Request: RequestDecodable, Response: ResponseEncodable
    {
        return self._on(method, to: path, bodyStream: bodyStream, use: closure)
    }
    
    private func _on<Request, Response>(
        _ method: HTTPMethod,
        to path: [PathComponent],
        bodyStream: HTTPBodyStreamStrategy = .collect,
        use closure: @escaping (Request, Context) throws -> Response
    ) -> Route
        where Request: RequestDecodable, Response: ResponseEncodable
    {
        let responder = BasicResponder(eventLoop: self.eventLoop) { req, ctx in
            if case .collect(let max) = bodyStream, let stream = req.body.stream {
                var req = req
                return stream.consume(max: max).flatMap { body in
                    req.body = HTTPBody(buffer: body)
                    return Request.decodeRequest(req, using: ctx).flatMapThrowing { req -> Response in
                        return try closure(req, ctx)
                    }.encodeResponse(for: req, using: ctx)
                }
            } else {
                return Request.decodeRequest(req, using: ctx).flatMapThrowing { req -> Response in
                    return try closure(req, ctx)
                }.encodeResponse(for: req, using: ctx)
            }
        }
        let route = Route(
            method: method,
            path: path,
            responder: responder,
            requestType: Request.self,
            responseType: Response.self
        )
        self.add(route)
        return route
    }
}

public final class Route {
    public var method: HTTPMethod
    public var path: [PathComponent]
    public var responder: Responder
    public var requestType: Any.Type
    public var responseType: Any.Type
    
    public var userInfo: [AnyHashable: Any]
    
    public init(
        method: HTTPMethod,
        path: [PathComponent],
        responder: Responder,
        requestType: Any.Type,
        responseType: Any.Type
    ) {
        self.method = method
        self.path = path
        self.responder = responder
        self.requestType = requestType
        self.responseType = responseType
        self.userInfo = [:]
    }
}

extension Route {
    @discardableResult
    public func description(_ string: String) -> Route {
        self.userInfo["description"] = string
        return self
    }
}
