import Routing

/// Capable of registering responder routes and returning
/// appropriate responders for a given request.
public protocol Router: class, Service {
    /// An array of routes that have been registered
    /// to this router.
    var routes: [Route<Responder>] { get }

    /// Registers a new route to this router.
    func register(route: Route<Responder>)

    /// Returns the appropriate responder for a given request,
    /// or nil if none was found.
    func route(request: Request) -> Responder?
}
