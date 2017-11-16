import HTTP

/// Routes requests to an appropriate responder. Can be used for custom router implementations
///
/// [For more information, see the documentation](https://docs.vapor.codes/3.0/routing/router/)
public protocol Router: class {
    /// All routes registered to this Router
    var routes: [Route] { get }
    
    /// Register a Route.
    func register(route: Route)

    /// Route the supplied request to a responder
    func route(request: Request) -> Responder?
}
