/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
public struct ApplicationResponder: Responder, ServiceType {
    /// See `ServiceType`.
    public static var serviceSupports: [Any.Type] { return [Responder.self] }

    /// See `ServiceType`.
    public static func makeService(for container: Container) throws -> ApplicationResponder {
        // initialize all `[Middleware]` from config
        let middleware = try container
            .make(MiddlewareConfig.self)
            .resolve(for: container)

        // create router and wrap in a responder
        let router = try container.make(Router.self)

        // return new responder
        return ApplicationResponder(router, middleware)
    }

    /// Wrapped `Responder`.
    private let responder: Responder

    /// Creates a new `ApplicationResponder`.
    public init(_ router: Router, _ middleware: [Middleware] = []) {
        let router = RouterResponder(router: router)
        let wrapped = middleware.makeResponder(chainingTo: router)
        self.responder = wrapped
    }

    /// See `Responder`.
    public func respond(to req: Request) throws -> Future<Response> {
        return try responder.respond(to: req)
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
    func respond(to req: Request) throws -> Future<Response> {
        guard let responder = router.route(request: req) else {
            let res = req.response(http: .init(status: .notFound, body: "Not found"))
            return req.eventLoop.newSucceededFuture(result: res)
        }

        return try responder.respond(to: req)
    }
}
