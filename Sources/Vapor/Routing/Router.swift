/// Capable of registering `Responder` routes and returning appropriate responders for a given request.
public protocol Router: class, Service {
    /// An array of `Route`s that have been registered to this router.
    var routes: [Route<Responder>] { get }

    /// Registers a new `Route` to this router.
    ///
    /// - parameters:
    ///     - route: New `Route` to register.
    func register(route: Route<Responder>)

    /// Returns the appropriate `Responder` for a given request, or `nil` if none was found.
    ///
    /// - parameters:
    ///     - request: `Request` to route.
    /// - returns: Matching `Responder` or `nil` if none was found.
    func route(request: Request) -> Responder?
}
