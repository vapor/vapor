import Foundation
import HTTPTypes
import Logging
import Metrics
import NIOCore
import RoutingKit

/// Vapor's main ``Responder`` type. Combines configured middleware + router to create a responder.
package struct DefaultResponder: Responder {
    /// It's safe to mark this `nonisolated(unsafe)` because there are only two mutating operations
    /// on a `TrieRouter` (calling `.register(_at:)` or changing its `options`), and we never do either
    /// of those after `init()`.
    private let router: TrieRouter<CachedRoute>
    private let notFoundResponder: any Responder
    private let reportMetrics: Bool

    private struct CachedRoute {
        let route: Route
        let responder: any Responder
    }

    /// Creates a new ``DefaultResponder``.
    package init(routes: Routes, middleware: [any Middleware] = [], reportMetrics: Bool = true) {
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
        self.reportMetrics = reportMetrics
    }

    // See `Responder.respond(to:)`
    package func respond(to request: Request) async throws -> Response {
        // per https://github.com/swiftlang/swift-testing/blob/swift-6.1-RELEASE/Sources/Testing/Events/TimeValue.swift#L113
        let epochDuration = unsafeBitCast((0, 0), to: ContinuousClock.Instant.self).duration(to: .now)
        let startTime = UInt64(epochDuration.components.seconds * 1_000_000_000 + (epochDuration.components.attoseconds / 1_000_000_000))

        let response: Response
        do {
            if let cachedRoute = self.getRoute(for: request) {
                request.route = cachedRoute.route
                response = try await cachedRoute.responder.respond(to: request)
            } else {
                response = try await self.notFoundResponder.respond(to: request)
            }
            let status = response.status
            if self.reportMetrics {
                let now = unsafeBitCast((0, 0), to: ContinuousClock.Instant.self).duration(to: .now)
                let nowNanos = UInt64(now.components.seconds * 1_000_000_000 + (now.components.attoseconds / 1_000_000_000))
                self.updateMetrics(
                    for: request,
                    elapsedTime: nowNanos - startTime,
                    statusCode: status.code
                )
            }
            return response
        } catch {
            let now = unsafeBitCast((0, 0), to: ContinuousClock.Instant.self).duration(to: .now)
            let nowNanos = UInt64(now.components.seconds * 1_000_000_000 + (now.components.attoseconds / 1_000_000_000))
            if self.reportMetrics {
                self.updateMetrics(
                    for: request,
                    elapsedTime: nowNanos - startTime,
                    statusCode: 500
                )
            }
            throw error
        }
    }
    
    /// Gets a `Route` from the underlying `TrieRouter`.
    private func getRoute(for request: Request) -> CachedRoute? {
        let pathComponents = request.url.path
            .split(separator: "/")
            .map(String.init)
        
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

    /// Records the requests metrics.
    private func updateMetrics(
        for request: Request,
        elapsedTime: UInt64,
        statusCode: Int
    ) {
        let pathForMetrics: String
        let methodForMetrics: String
        if let route = request.route {
            // We don't use route.description here to avoid duplicating the method in the path
            pathForMetrics = "/\(route.path.map { "\($0)" }.joined(separator: "/"))"
            methodForMetrics = request.method.rawValue
        } else {
            // If the route is undefined (i.e. a 404 and not something like /users/:userID
            // We rewrite the path and the method to undefined to avoid DOSing the
            // application and any downstream metrics systems. Otherwise an attacker
            // could spam the service with unlimited requests and exhaust the system
            // with unlimited timers/counters
            pathForMetrics = "vapor_route_undefined"
            methodForMetrics = "undefined"
        }
        let dimensions = [
            ("method", methodForMetrics),
            ("path", pathForMetrics),
            ("status", statusCode.description),
        ]
        Counter(label: "http_requests_total", dimensions: dimensions).increment()
        if statusCode >= 500 {
            Counter(label: "http_request_errors_total", dimensions: dimensions).increment()
        }
        Timer(
            label: "http_request_duration_seconds",
            dimensions: dimensions,
            preferredDisplayUnit: .seconds
        ).recordNanoseconds(elapsedTime)
    }
}

private struct NotFoundResponder: Responder {
    func respond(to request: Request) async throws -> Response {
        throw RouteNotFound()
    }
}

struct RouteNotFound: Error {}

extension RouteNotFound: AbortError {    
    var status: HTTPResponse.Status {
        .notFound
    }
}

extension RouteNotFound: DebuggableError {
    var logLevel: Logger.Level { 
        .debug
    }
}
