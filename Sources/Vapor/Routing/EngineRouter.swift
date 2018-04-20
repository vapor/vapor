import Routing
import Bits
import Foundation

/// An HTTP wrapper around the TrieNodeRouter
public final class EngineRouter: Router {
    /// The internal router
    private let router: Routing.Router<Responder>

    private let notFound: Responder

    /// See Router.routes
    public var routes: [Route<Responder>] {
        return router.routes
    }

    /// Create a new engine router
    public init(caseInsensitive: Bool) {
        self.router = .init()
        if caseInsensitive {
            self.router.options.insert(.caseInsensitive)
        }
        let notFoundRes = HTTPResponse(status: .notFound, body: "Not found")
        self.notFound = BasicResponder { req in
            let res = req.makeResponse()
            res.http = notFoundRes
            return req.eventLoop.newSucceededFuture(result: res)
        }
    }

    /// Create a new engine router with default settings.
    public static func `default`() -> EngineRouter {
        return EngineRouter(caseInsensitive: false)
    }

    /// See Router.register
    public func register(route: Route<Responder>) {
        router.register(route: route)
    }

    /// See Router.route
    public func route(request: Request) -> Responder? {
        // FIXME: use NIO's underlying uri byte buffer when possible
        // instead of converting to string. `router.route` accepts conforming to `RoutablePath`
        let path: [String] = request.http.urlString
            .split(separator: "?")[0]
            .split(separator: "/").map { .init($0) }
        return router.route(path:  [request.http.method.string] + path, parameters: &request._parameters) ?? notFound
    }
}

extension HTTPMethod {
    var string: String {
        switch self {
        case .GET: return "GET"
        default: return "\(self)"
        }
    }

    var pathComponent: PathComponent {
        return .constant(string)
    }
}
