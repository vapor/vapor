import HTTP
import Routing

/// Groups routes
///
/// Every route will have the properties of this Group added
///
/// All path components will be inserted before the Route's path
///
/// All middleware will be applied to the Responder
public final class Group : Router {
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
    public func group(_ path: PathComponentRepresentable..., use: ((Group) -> ())) {
        use(Group(cascadingTo: self, components: path.makePathComponents()))
    }
    
    /// Creates a group with the provided path components
    public func grouped(_ path: PathComponentRepresentable...) -> Group {
        return Group(cascadingTo: self, components: path.makePathComponents())
    }
    
    /// Creates a group with the provided middleware and hands it to the closure
    public func group(_ middleware: Middleware..., use: ((Group) -> ())) {
        use(Group(cascadingTo: self, middleware: middleware))
    }
    
    /// Creates a group with the provided middleware
    public func grouped(_ middleware: Middleware...) -> Group {
        return Group(cascadingTo: self, middleware: middleware)
    }
}
