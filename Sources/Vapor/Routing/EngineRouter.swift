///// An HTTP wrapper around the TrieNodeRouter
//public final class EngineRouter: Router {
//    /// Create a new `EngineRouter` with default settings.
//    ///
//    /// Currently this creates an `EngineRouter` with case-sensitive routing but
//    /// this may change in the future.
//    public static func `default`(eventLoop: EventLoop) -> EngineRouter {
//        return EngineRouter(caseInsensitive: false, eventLoop: eventLoop)
//    }
//
//    /// The internal router
//    private let router: TrieRouter<HTTPResponder>
//    
//    public var eventLoop: EventLoop
//
//    /// See `Router`.
//    public var routes: [Route<HTTPResponder>] {
//        return router.routes
//    }
//
//    /// Create a new `EngineRouter`.
//    ///
//    /// - parameters:
//    ///     - caseInsensitive: If `true`, route matching will be case-insensitive.
//    public init(caseInsensitive: Bool, eventLoop: EventLoop) {
//        self.router = .init()
//        if caseInsensitive {
//            self.router.options.insert(.caseInsensitive)
//        }
//        self.eventLoop = eventLoop
//    }
//
//    /// See `Router`.
//    public func register(route: Route<HTTPResponder>) {
//        router.register(route: route)
//    }
//
//    /// See `Router`.
//    public func route(request: HTTPRequestContext) -> HTTPResponder? {
//        // FIXME: use NIO's underlying uri byte buffer when possible
//        // instead of converting to string. `router.route` accepts conforming to `RoutableComponent`
//        let path: [Substring] = request.http.urlString
//            .split(separator: "?", maxSplits: 1)[0]
//            .split(separator: "/")
//        return router.route(path: [request.http.method.substring] + path, parameters: &request._parameters)
//    }
//}
//
