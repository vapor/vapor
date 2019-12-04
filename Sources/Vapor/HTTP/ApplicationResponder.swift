/// Vapor's main `Responder` type. Responds based on the Route it receives.
public struct ApplicationResponder: Responder {
    /// Creates a new `RouteResponder`.
    public init() { }

    /// See `Responder`.
    public func respond(to request: Request, on route: Route) -> EventLoopFuture<Response> {
        request.logger.info("\(request.method) \(request.url.path)")
        return route.responder.respond(to: request, on: route)
            .hop(to: request.eventLoop)
    }
}
