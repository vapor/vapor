public import HTTPTypes
public import Logging
import RoutingKit

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Vapor's main ``Responder`` type. Combines configured middleware + router to create a responder.
package struct DefaultResponder: Responder {
    private let router: TrieRouter<CachedRoute>
    private let notFoundResponder: any Responder

    private struct CachedRoute {
        let route: Route
        let responder: any Responder
    }

    /// Creates a new ``DefaultResponder``.
    package init(routes: RouteStorage, middleware: [any Middleware] = []) {
        let config = TrieRouter<CachedRoute>.Configuration(
            isCaseInsensitive: routes.caseInsensitive
        )
        var routerBuilder = TrieRouterBuilder(CachedRoute.self, config: config)
        var registeredMethods: [HTTPRequest.Method] = []

        for route in routes.all {
            if !registeredMethods.contains(route.method) {
                registeredMethods.append(route.method)
            }

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
        let router = routerBuilder.build()
        self.router = router
        self.notFoundResponder = middleware.makeResponder(
            chainingTo: UnmatchedRouteResponder(router: router, registeredMethods: registeredMethods)
        )
    }

    // See `Responder.respond(to:)`
    package func respond(to request: Request) async throws -> Response {
        var parameters = Parameters()
        guard
            let cachedRoute = self.getRoute(
                method: request.method,
                path: request.url.path,
                parameters: &parameters
            )
        else {
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
        let pathComponents = Self.pathComponents(path)

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
        guard
            let route = self.router.route(
                path: [resolvedMethod.rawValue] + pathComponents,
                parameters: &routeParameters
            )
        else {
            return nil
        }
        parameters = routeParameters
        return route
    }

    private static func pathComponents(_ path: String) -> [String] {
        path
            .split(separator: "/")
            .map { String($0).removingPercentEncoding ?? String($0) }
    }

    /// Answers requests no route matched: 405 when the path is routed for other methods, 404 otherwise.
    ///
    /// Only reached on a miss, so matched requests never pay for probing the other methods.
    private struct UnmatchedRouteResponder: Responder {
        let router: TrieRouter<CachedRoute>
        let registeredMethods: [HTTPRequest.Method]

        func respond(to request: Request) async throws -> Response {
            // Routing already missed for the request's own method, and for GET when it is a HEAD request.
            let candidates = self.registeredMethods.filter { method in
                method != request.method && !(request.method == .head && method == .get)
            }
            guard !candidates.isEmpty else {
                throw RouteNotFound()
            }

            var path = [""] + DefaultResponder.pathComponents(request.url.path)
            // Only whether a route matches is used, so every probe shares one throwaway `Parameters`;
            // creating one per probe would also create a `Logger` per probe.
            var parameters = Parameters()
            var allowedMethods = candidates.filter { method in
                path[0] = method.rawValue
                return self.router.route(path: path, parameters: &parameters) != nil
            }
            guard !allowedMethods.isEmpty else {
                throw RouteNotFound()
            }
            // GET routes also answer HEAD.
            if allowedMethods.contains(.get), !allowedMethods.contains(.head) {
                allowedMethods.append(.head)
            }
            throw MethodNotAllowed(allowedMethods: allowedMethods.sorted { $0.rawValue < $1.rawValue })
        }
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

/// Thrown when no route matches a request's method, but routes for other methods match its path.
public struct MethodNotAllowed: Error {
    /// The methods the path is routed for, sent back in the `Allow` header.
    ///
    /// Includes `HEAD` wherever `GET` is routed, since `GET` routes also answer `HEAD` requests.
    public let allowedMethods: [HTTPRequest.Method]

    public init(allowedMethods: [HTTPRequest.Method]) {
        self.allowedMethods = allowedMethods
    }
}

extension MethodNotAllowed: AbortError {
    public var status: HTTPResponse.Status {
        .methodNotAllowed
    }

    public var headers: HTTPFields {
        [.allow: self.allowedMethods.map(\.rawValue).joined(separator: ", ")]
    }
}

extension MethodNotAllowed: DebuggableError {}
