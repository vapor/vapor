import Async
import HTTP
import Routing

/// Converts a router into a responder.
public struct RouterResponder: Responder {
    let router: Router
    public init(router: Router) {
        self.router = router
    }

    public func respond(to req: Request) throws -> Future<Response> {
        guard let responder = router.route(request: req) else {
            return Future(Response(status: .notFound))
        }

        return try responder.respond(to: req)
    }
}

extension TrieRouter: AsyncRouter, SyncRouter { }
