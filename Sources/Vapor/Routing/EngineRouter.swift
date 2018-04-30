/// An HTTP wrapper around the TrieNodeRouter
public final class EngineRouter: Router {
    /// Create a new `EngineRouter` with default settings.
    ///
    /// Currently this creates an `EngineRouter` with case-sensitive routing but
    /// this may change in the future.
    public static func `default`() -> EngineRouter {
        return EngineRouter(caseInsensitive: false)
    }

    /// The internal router
    private let router: TrieRouter<Responder>

    /// Default not found responder.
    private let notFound: Responder

    /// See `Router`.
    public var routes: [Route<Responder>] {
        return router.routes
    }

    /// Create a new `EngineRouter`.
    ///
    /// - parameters:
    ///     - caseInsensitive: If `true`, route matching will be case-insensitive.
    public init(caseInsensitive: Bool) {
        self.router = .init()
        if caseInsensitive {
            self.router.options.insert(.caseInsensitive)
        }
        let notFoundRes = HTTPResponse(status: .notFound, body: "Not found")
        self.notFound = BasicResponder { req in
            let res = req.makeResponse()
            res.http = notFoundRes
            return req.eventLoop.newSucceededFuture(result: res)
        }
    }

    /// See `Router`.
    public func register(route: Route<Responder>) {
        router.register(route: route)
    }

    /// See `Router`.
    public func route(request: Request) -> Responder? {
        // FIXME: use NIO's underlying uri byte buffer when possible
        // instead of converting to string. `router.route` accepts conforming to `RoutablePath`
        let path: [String] = request.http.urlString
            .split(separator: "?")[0]
            .split(separator: "/").map { .init($0) }
        return router.route(path:  [request.http.method.string] + path, parameters: &request._parameters) ?? notFound
    }
}
