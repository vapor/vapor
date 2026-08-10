#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
public import HTTPTypes
public import Logging
import NIOCore
import RoutingKit

/// Vapor's main ``Responder`` type. Combines configured middleware + router to create a responder.
///
/// Prefer ``Application/makeResponder()``, which returns this or a provided responder as
/// configured. Build one directly only when you need a responder over a specific set of routes and
/// middleware, independent of an ``Application``.
public struct DefaultResponder: Responder {
    /// It's safe to mark this `nonisolated(unsafe)` because there are only two mutating operations
    /// on a `TrieRouter` (calling `.register(_at:)` or changing its `options`), and we never do either
    /// of those after `init()`.
    private let router: TrieRouter<CachedRoute>
    private let notFoundResponder: any Responder

    private struct CachedRoute {
        let route: Route
        let responder: any Responder
    }

    /// Creates a new ``DefaultResponder``.
    public init(routes: Routes, middleware: [any Middleware] = []) {
        let config = TrieRouter<CachedRoute>.Configuration(
            isCaseInsensitive: routes.caseInsensitive
        )
        var routerBuilder = TrieRouterBuilder(CachedRoute.self, config: config)

        for route in routes.all {
            // Make a copy of the route to cache middleware chaining.
            let cached = CachedRoute(
                route: route,
                responder: middleware.makeResponder(chainingTo: route.responder)
            )

            // remove any empty path components
            let path = route.path.filter { component in
                switch component {
                case .constant(let string): string != ""
                default: true
                }
            }

            routerBuilder.register(cached, at: [.constant(route.method.rawValue)] + path)
        }
        self.router = routerBuilder.build()
        self.notFoundResponder = middleware.makeResponder(chainingTo: NotFoundResponder())
    }

    // See `Responder.respond(to:)`
    public func respond(to request: Request) async throws -> Response {
        if let cachedRoute = self.getRoute(for: request) {
            request.route = cachedRoute.route
            return try await cachedRoute.responder.respond(to: request)
        } else {
            return try await self.notFoundResponder.respond(to: request)
        }
    }

    /// Gets a `Route` from the underlying `TrieRouter`.
    private func getRoute(for request: Request) -> CachedRoute? {
        let pathComponents = request.url.path
            .split(separator: "/")
            .map { String($0).removingPercentEncoding ?? String($0) }

        // If it's a HEAD request and a HEAD route exists, return that route...
        if request.method == .head, let route = self.router.route(
            path: [HTTPRequest.Method.head.rawValue] + pathComponents,
            parameters: &request.parameters
        ) {
            return route
        }

        // ...otherwise forward HEAD requests to GET route
        let method = (request.method == .head) ? .get : request.method

        return self.router.route(
            path: [method.rawValue] + pathComponents,
            parameters: &request.parameters
        )
    }
}

private struct NotFoundResponder: Responder {
    func respond(to request: Request) async throws -> Response {
        throw RouteNotFound()
    }
}

public struct RouteNotFound: Error {}

extension RouteNotFound: AbortError {
    public var status: HTTPResponse.Status {
        .notFound
    }
}

extension RouteNotFound: DebuggableError {
    public var logLevel: Logger.Level {
        .debug
    }
}

extension Application {
    /// The ``Responder`` that handles requests for this application.
    ///
    /// This is the entry point Vapor's HTTP server uses once a request has been parsed off the
    /// wire, so calling it exercises the same path a live request takes — routing, the middleware
    /// stack, handler dispatch and response encoding — without needing a socket.
    ///
    /// Useful for driving an application in-process: test harnesses, serverless adapters and
    /// benchmarks.
    public func makeResponder() -> any Responder {
        switch self.responder {
        case .default:
            DefaultResponder(routes: self.routes, middleware: self.middleware.resolve())
        case .provided(let responder):
            responder
        }
    }
}
