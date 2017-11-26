import HTTP
import Routing

/// Groups routes
///
/// Every route will have the properties of this Group added
///
/// All path components will be inserted before the Route's path
///
/// All middleware will be applied to the Responder
///
/// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/)
public final class RouteGroup: Router {
    /// All routes registered to this group
    public private(set) var routes: [Route] = []
    
    let `super`: Router
    let components: [PathComponent]
    let middleware: [Middleware]
    
    /// Creates a new group
    ///
    /// All path components will be inserted before the Route's path
    ///
    /// All middleware will be applied to the Responder
    public init(cascadingTo router: Router, components: [PathComponent] = [], middleware: [Middleware] = []) {
        self.super = router
        self.components = components
        self.middleware = middleware
    }
    
    /// Registers a route to this `Group`.
    ///
    /// Warning: Will modify the route
    public func register(route: Route) {
        self.routes.append(route)
        route.path.insert(contentsOf: self.components, at: 0)
        route.responder = middleware.makeResponder(chainedto: route.responder)
        self.super.register(route: route)
    }
    
    /// Routes a request, this feature should not be used normally
    public func route(request: Request) -> Responder? {
        return self.super.route(request: request)
    }
}

extension Router {
    /// Creates a group with the provided path components and hands it to the closure
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    public func group(_ path: PathComponent..., use: ((RouteGroup) -> ())) {
        use(RouteGroup(cascadingTo: self, components: path))
    }
    
    /// Creates a group with the provided path components
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#path-components)
    public func grouped(_ path: PathComponent...) -> RouteGroup {
        return RouteGroup(cascadingTo: self, components: path)
    }
    
    /// Creates a group with the provided middleware and hands it to the closure
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#middleware)
    public func group(_ middleware: Middleware..., use: ((RouteGroup) -> ())) {
        use(RouteGroup(cascadingTo: self, middleware: middleware))
    }
    
    /// Creates a group with the provided middleware
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/vapor/route-group/#middleware)
    public func grouped(_ middleware: Middleware...) -> RouteGroup {
        return RouteGroup(cascadingTo: self, middleware: middleware)
    }
}
