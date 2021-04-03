import Metrics

/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
internal struct DefaultResponder: Responder {
    private let router: AnyRouter<CachedRoute>
    private let notFoundResponder: Responder

    private struct CachedRoute {
        let route: Route
        let responder: Responder
    }

    /// Creates a new `ApplicationResponder`
    internal init(routes: Routes, routerFactory: RouterFactory, middleware: [Middleware] = []) {
        let router = routerFactory.buildRouter(forOutputType: CachedRoute.self)
        
        for route in routes.all {
            // Make a copy of the route to cache middleware chaining.
            let cached = CachedRoute(
                route: route,
                responder: middleware.makeResponder(chainingTo: route.responder)
            )
            // remove any empty path components
            let path = route.path.filter { component in
                switch component {
                case .constant(let string):
                    return string != ""
                default:
                    return true
                }
            }
            
            // If the route isn't explicitly a HEAD route,
            // and it's made up solely of .constant components,
            // register a HEAD route with the same path
            if route.method == .GET &&
                route.path.allSatisfy({ component in
                    if case .constant(_) = component { return true }
                    return false
            }) {
                let headRoute = Route(
                    method: .HEAD,
                    path: cached.route.path,
                    responder: middleware.makeResponder(chainingTo: HeadResponder()),
                    requestType: cached.route.requestType,
                    responseType: cached.route.responseType)

                let headCachedRoute = CachedRoute(route: headRoute, responder: middleware.makeResponder(chainingTo: HeadResponder()))

                router.register(headCachedRoute, at: [.constant(HTTPMethod.HEAD.string)] + path)
            }
            
            router.register(cached, at: [.constant(route.method.string)] + path)
        }
        self.router = router
        self.notFoundResponder = middleware.makeResponder(chainingTo: NotFoundResponder())
    }

    /// See `Responder`
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        let startTime = DispatchTime.now().uptimeNanoseconds
        let response: EventLoopFuture<Response>
        if let cachedRoute = self.getRoute(for: request) {
            request.route = cachedRoute.route
            response = cachedRoute.responder.respond(to: request)
        } else {
            response = self.notFoundResponder.respond(to: request)
        }
        return response.always { result in
            let status: HTTPStatus
            switch result {
            case .success(let response):
                status = response.status
            case .failure:
                status = .internalServerError
            }
            self.updateMetrics(
                for: request,
                startTime: startTime,
                statusCode: status.code
            )
        }
    }
    
    /// Gets a `Route` from the underlying `TrieRouter`.
    private func getRoute(for request: Request) -> CachedRoute? {
        let pathComponents = request.url.path
            .split(separator: "/")
            .map(String.init)
        
        // If it's a HEAD request and a HEAD route exists, return that route...
        if request.method == .HEAD, let route = self.router.route(
            path: [HTTPMethod.HEAD.string] + pathComponents,
            parameters: &request.parameters
        ) {
            return route
        }

        // ...otherwise forward HEAD requests to GET route
        let method = (request.method == .HEAD) ? .GET : request.method
        
        return self.router.route(
            path: [method.string] + pathComponents,
            parameters: &request.parameters
        )
    }

    /// Records the requests metrics.
    private func updateMetrics(
        for request: Request,
        startTime: UInt64,
        statusCode: UInt
    ) {
        let pathForMetrics: String
        let methodForMetrics: String
        if let route = request.route {
            // We don't use route.description here to avoid duplicating the method in the path
            pathForMetrics = "/\(route.path.map { "\($0)" }.joined(separator: "/"))"
            methodForMetrics = request.method.string
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
        ).recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
    }
}

private struct HeadResponder: Responder {
    func respond(to request: Request) -> EventLoopFuture<Response> {
        request.eventLoop.makeSucceededFuture(.init(status: .ok))
    }
}

private struct NotFoundResponder: Responder {
    func respond(to request: Request) -> EventLoopFuture<Response> {
        request.eventLoop.makeFailedFuture(RouteNotFound())
    }
}

struct RouteNotFound: Error {
    let stackTrace: StackTrace?

    init() {
        self.stackTrace = StackTrace.capture(skip: 1)
    }
}

extension RouteNotFound: AbortError {    
    var status: HTTPResponseStatus {
        .notFound
    }
}

extension RouteNotFound: DebuggableError {
    var logLevel: Logger.Level { 
        .debug
    }
}
