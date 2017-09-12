import Routing

/// An object that can register it's routes to a router
public protocol RouteCollection {
    /// Registers all routes to a router
    func register(to router: Router)
}
