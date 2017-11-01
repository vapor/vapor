import HTTP

/// Routes requests to an appropriate responder. Can be used for custom router implementations
///
/// http://localhost:8000/routing/router/
public protocol Router: class {
    /// All routes registered to this Router
    var routes: [Route] { get }
    
    /// Register a Route.
    func register(route: Route)

    /// Route the supplied request to a responder
    func route(request: Request) -> Responder?
}
