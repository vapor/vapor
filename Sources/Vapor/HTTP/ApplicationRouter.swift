/// Gets a `Route` from a `Request`.
public struct ApplicationRouter: Router {
    private let router: TrieRouter<Route>
    private let middleware: [Middleware]
    private let notFoundRoute: Route
        
    /// Creates a new `RouterResponder`.
    init(routes: Routes, middleware: [Middleware]) {
        // We create & store this at init time to not impact performance later on in the application.
        // This `Route` is used to return a 404 response, instead of an error.
        let notFoundResponder = middleware.makeResponder(chainingTo: BasicResponder(closure: { _ in throw Abort(.notFound) }))
        self.notFoundRoute = Route(method: .GET, path: [], responder: notFoundResponder, requestType: Request.self, responseType: Response.self)
        self.router = TrieRouter(Route.self)
        self.middleware = middleware
        for route in routes.all {
            route.responder = middleware.makeResponder(chainingTo: route.responder)
            // remove any empty path components
            let path = route.path.filter { component in
                switch component {
                case .constant(let string):
                    return string != ""
                default:
                    return true
                }
            }
            let route = RoutingKit.Route<Route>(
                path: [.constant(route.method.string)] + path,
                output: route
            )
            router.register(route: route)
        }
    }
    
    /// See `Router`.
    public func getRoute(for request: Request) -> Result<Route, Error> {
        let pathComponents = request.url.path
            .split(separator: "/")
            .map(String.init)
        
        let method = (request.method == .HEAD) ? .GET : request.method
        
        guard let route = self.router.route(
            path: [method.string] + pathComponents,
            parameters: &request.parameters
        ) else {
            return .success(notFoundRoute)
        }
        request.route = route
        return .success(route)
    }
}
