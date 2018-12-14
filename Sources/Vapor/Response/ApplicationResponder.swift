/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
public struct ApplicationResponder: HTTPResponder {
    /// Wrapped `Responder`.
    private let responder: HTTPResponder

    /// Creates a new `ApplicationResponder`.
    public init(_ router: Router, _ middleware: [HTTPMiddleware] = []) {
        let router = RouterResponder(router: router)
        let wrapped = middleware.makeResponder(chainingTo: router)
        self.responder = wrapped
    }

    /// See `Responder`.
    public func respond(to req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        return responder.respond(to: req)
    }
}

// MARK: Private

/// Converts a `Router` into a `Responder`.
private struct RouterResponder: HTTPResponder {
    let router: Router

    /// Creates a new `RouterResponder`.
    init(router: Router) {
        self.router = router
    }

    /// See `Responder`.
    func respond(to req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        guard let responder = self.router.route(request: req) else {
            let res = HTTPResponse(status: .notFound, body: "Not found")
            return self.router.eventLoop.makeSucceededFuture(result: res)
        }

        return responder.respond(to: req)
    }
}
