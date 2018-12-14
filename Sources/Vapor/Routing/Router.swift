/// Capable of registering `Responder` routes and returning appropriate responders for a given request.
public protocol Router: class {
    var eventLoop: EventLoop { get }
    
    /// An array of `Route`s that have been registered to this router.
    var routes: [Route<HTTPResponder>] { get }

    /// Registers a new `Route` to this router.
    ///
    /// - parameters:
    ///     - route: New `Route` to register.
    func register(route: Route<HTTPResponder>)

    /// Returns the appropriate `Responder` for a given request, or `nil` if none was found.
    ///
    /// - parameters:
    ///     - request: `Request` to route.
    /// - returns: Matching `Responder` or `nil` if none was found.
    func route(request: HTTPRequest) -> HTTPResponder?
}
