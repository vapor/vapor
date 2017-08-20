import HTTP

/// FIXME: just for testing
public final class TestRouter: Router {
    var storage: [String: Responder]

    public init() {
        storage = [:]
    }

    public func register(responder: Responder, path: [String]) {
        let path = "/" + path.joined(separator: "/")
        storage[path] = responder
    }

    public func route(request: Request) -> Responder? {
        guard let responder = storage[request.uri.path] else {
            return nil
        }

        return responder
    }
}

// FIXME: just for testing
// TODO: needs to take into account the middleware
public struct RouterResponder: Responder {
    let router: Router
    public init(router: Router) {
        self.router = router
    }

    public func respond(to req: Request, using writer: ResponseWriter) throws {
        guard let responder = router.route(request: req) else {
            fatalError("No route")
        }

        try responder.respond(to: req, using: writer)
    }
}
