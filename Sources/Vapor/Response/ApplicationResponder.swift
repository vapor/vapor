/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
public struct ApplicationResponder: Responder, ServiceType {
    /// See `ServiceType`.
    static var serviceSupports: [Any.Type] { return [Responder.self] }

    /// See `ServiceType`.
    static func makeService(for container: Container) throws -> ApplicationResponder {
        // initialize all `[Middleware]` from config
        let middleware = try container
            .make(MiddlewareConfig.self)
            .resolve(for: container)

        // create router and wrap in a responder
        let router = try RouterResponder(router: container.make())

        // chain middleware to router
        let wrapped = middleware.makeResponder(chainedto: router)

        // return new responder
        return ApplicationResponder(wrapped)
    }

    /// Wrapped `Responder`.
    private let responder: Responder

    /// Creates a new `ApplicationResponder`.
    init(_ responder: Responder) {
        self.responder = responder
    }

    /// See `Responder`.
    func respond(to req: Request) throws -> Future<Response> {
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
            let res = req.makeResponse(http: .init(status: .notFound, body: "Not found"))
            return req.eventLoop.newSucceededFuture(result: res)
        }

        return try responder.respond(to: req)
    }
}
