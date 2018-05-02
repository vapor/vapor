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
    }

    /// See `Router`.
    public func register(route: Route<Responder>) {
        router.register(route: route)
    }

    /// See `Router`.
    public func route(request: Request) -> Responder? {
        let method = Substring(request.http.method.string)
        // FIXME: use NIO's underlying uri byte buffer when possible
        // instead of converting to string. `router.route` accepts conforming to `RoutableComponent`
        let path: [Substring] = request.http.urlString
            .split(separator: "?")[0]
            .split(separator: "/")
        return router.route(path:  [method] + path, parameters: &request._parameters)
    }
}

extension Substring: RoutableComponent {
    /// See `RoutableComponent`.
    public var routerParameterValue: String { return .init(self) }

    /// See `RoutableComponent`.
    public func routerCompare(to buffer: UnsafeRawBufferPointer, options: Set<RouterOption>) -> Bool {
        return Data(utf8).routerCompare(to: buffer, options: options)
    }
}
