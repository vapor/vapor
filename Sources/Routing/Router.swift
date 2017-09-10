import HTTP

/// Routes requests to an appropriate responder.
public protocol Router: class {
    /// Register a Route.
    func register(route: Route)

    /// Route the supplied request to a responder
    func route(request: Request) -> Responder?
}
