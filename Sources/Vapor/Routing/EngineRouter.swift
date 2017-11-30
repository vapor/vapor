import Routing

/// An HTTP wrapper around the TrieNodeRouter
public final class EngineRouter: Router {
    /// The internal router
    private let router: TrieRouter<Responder>

    /// See Router.routes
    public var routes: [Route<Responder>] {
        return router.routes
    }

    /// Create a new engine router
    public init() {
        self.router = .init()
    }

    /// Create a new engine router with default settings.
    public static func `default`() -> EngineRouter {
        let router = EngineRouter()
        router.router.fallback = BasicResponder { req in
            let res = req.makeResponse()
            res.http.status = .notFound
            res.http.body = HTTPBody(string: "Not found")
            return Future(res)
        }
        return router
    }

    /// See Router.register
    public func register(route: Route<Responder>) {
        router.register(route: route)
    }

    /// See Router.route
    public func route(request: Request) -> Responder? {
        return router.route(
            path: [request.http.method.data] + request.http.uri.pathData.split(separator: .forwardSlash),
            parameters: request.parameters
        )
    }
}
