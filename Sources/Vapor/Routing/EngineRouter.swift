import Routing
import Bits
import Foundation

/// An HTTP wrapper around the TrieNodeRouter
public final class EngineRouter: Router {
    /// The internal router
    private let router: TrieRouter<Responder>

    /// See Router.routes
    public var routes: [Route<Responder>] {
        return router.routes
    }

    /// Create a new engine router
    public init(caseInsensitive: Bool) {
        self.router = .init()
        self.router.caseInsensitive = caseInsensitive
    }

    /// Create a new engine router with default settings.
    public static func `default`() -> EngineRouter {
        let router = EngineRouter(caseInsensitive: false)
        router.router.fallback = BasicResponder { req in
            let res = req.makeResponse()
            res.http.status = .notFound
            res.http.body = HTTPBody(string: "Not found")
            return Future.map(on: req) { res }
        }
        return router
    }

    /// See Router.register
    public func register(route: Route<Responder>) {
        router.register(route: route)
    }

    /// See Router.route
    public func route(request: Request) -> Responder? {
        return router.route(
            path:  [request.http.method.pathComponent] + request.http.urlString.split(separator: "/").map { .init(substring: $0) },
            parameters: request
        )
    }
}

extension HTTPMethod {
    var pathComponent: PathComponent {
        switch self {
        case .GET: return .init(bytes: _getData.withByteBuffer { $0 })
        default: return .init(string: "\(self)")
        }
    }
}

private let _getData = Data("GET".utf8)
