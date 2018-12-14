/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
public struct ApplicationResponder: Responder {
    /// Wrapped `Responder`.
    private let responder: Responder

    /// Creates a new `ApplicationResponder`.
    public init(_ router: Router, _ middleware: [Middleware] = []) {
        let router = RouterResponder(router: router)
        let wrapped = middleware.makeResponder(chainingTo: router)
        self.responder = wrapped
    }

    /// See `Responder`.
    public func respond(to req: HTTPRequestContext) -> EventLoopFuture<HTTPResponse> {
        return responder.respond(to: req)
    }
}

// MARK: Private

/// Converts a `Router` into a `Responder`.
private struct RouterResponder: Responder {
    let router: Router

    /// Creates a new `RouterResponder`.
    init(router: Router) {
        self.router = router
    }

    /// See `Responder`.
    func respond(to req: HTTPRequestContext) -> EventLoopFuture<HTTPResponse> {
        guard let responder = self.router.route(request: req) else {
            let res = HTTPResponse(status: .notFound, body: "Not found")
            return req.eventLoop.makeSucceededFuture(result: res)
        }

        return responder.respond(to: req)
    }
}
