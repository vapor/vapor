#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
public import HTTPTypes
public import Logging
import RoutingKit

/// Vapor's main ``Responder`` type. Combines configured middleware + router to create a responder.
package struct DefaultResponder: Responder {
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
    package init(routes: Routes, middleware: [any Middleware] = []) {
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
    package func respond(to request: Request) async throws -> Response {
        var parameters = Parameters()
        guard let cachedRoute = self.getRoute(
            method: request.method,
            path: request.url.path,
            parameters: &parameters
        ) else {
            return try await self.notFoundResponder.respond(to: request)
        }
        return try await cachedRoute.responder.respond(
            to: Request(request, route: cachedRoute.route, parameters: parameters)
        )
    }

    /// Gets a `Route` from the underlying `TrieRouter`.
    private func getRoute(
        method: HTTPRequest.Method,
        path: String,
        parameters: inout Parameters
    ) -> CachedRoute? {
        let pathComponents = path
            .split(separator: "/")
            .map { String($0).removingPercentEncoding ?? String($0) }

        // If it's a HEAD request and a HEAD route exists, return that route...
        if method == .head {
            var headParameters = Parameters()
            if let route = self.router.route(
                path: [HTTPRequest.Method.head.rawValue] + pathComponents,
                parameters: &headParameters
            ) {
                parameters = headParameters
                return route
            }
        }

        // ...otherwise forward HEAD requests to GET route
        let resolvedMethod = (method == .head) ? .get : method

        var routeParameters = Parameters()
        guard let route = self.router.route(
            path: [resolvedMethod.rawValue] + pathComponents,
            parameters: &routeParameters
        ) else {
            return nil
        }
        parameters = routeParameters
        return route
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
