/// Gets a `Route` from a `Request`.
internal struct ApplicationRouter: Router {
    private let router: TrieRouter<Route>

    let middleware: [Middleware]
        
    /// Creates a new `RouterResponder`.
    init(routes: Routes, middleware: [Middleware]) {
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
    func getRoute(for request: Request) -> Result<Route, Error> {
        let pathComponents = request.url.path
            .split(separator: "/")
            .map(String.init)
        
        let method = (request.method == .HEAD) ? .GET : request.method
        
        guard let route = self.router.route(
            path: [method.string] + pathComponents,
            parameters: &request.parameters
        ) else {
            return .failure(Abort(.notFound))
        }
        return .success(route)
    }
}
