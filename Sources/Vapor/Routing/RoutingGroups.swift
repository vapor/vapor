import HTTP
import Routing

extension Router {
    /// Creates a group with the provided path components and hands it to the closure
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    public func group(_ path: PathComponent..., use: ((Router) -> ())) {
        use(RouteGroup(cascadingTo: self, components: path))
    }

    /// Creates a group with the provided path components
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    public func grouped(_ path: PathComponent...) -> Router {
        return RouteGroup(cascadingTo: self, components: path)
    }

    /// Creates a group with the provided middleware and hands it to the closure
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#middleware)
    public func group(_ middleware: Middleware..., use: ((Router) -> ())) {
        use(RouteGroup(cascadingTo: self, middleware: middleware))
    }

    /// Creates a group with the provided middleware
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#middleware)
    public func grouped(_ middleware: Middleware...) -> Router {
        return RouteGroup(cascadingTo: self, middleware: middleware)
    }
}

/// Groups routes
///
/// Every route will have the properties of this Group added
///
/// All path components will be inserted before the Route's path
///
/// All middleware will be applied to the Responder
///
/// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/)
fileprivate final class RouteGroup: Router {
    /// All routes registered to this group
    private(set) var routes: [Route<Responder>] = []

    let `super`: Router
    let components: [PathComponent]
    let middleware: [Middleware]
    
    /// Creates a new group
    ///
    /// All path components will be inserted before the Route's path
    ///
    /// All middleware will be applied to the Responder
    init(cascadingTo router: Router, components: [PathComponent] = [], middleware: [Middleware] = []) {
        self.super = router
        self.components = components
        self.middleware = middleware
    }
    
    /// Registers a route to this `Group`.
    ///
    /// Warning: Will modify the route
    func register(route: Route<Responder>) {
        self.routes.append(route)
        // Right after the method
        route.path.insert(contentsOf: self.components, at: 1)
        route.output = middleware.makeResponder(chainedto: route.output)
        self.super.register(route: route)
    }
    
    /// Routes a request, this feature should not be used normally
    func route(request: Request) -> Responder? {
        return self.super.route(request: request)
    }
}
