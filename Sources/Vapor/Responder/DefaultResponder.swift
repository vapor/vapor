import Metrics
import Tracing
import TracingOpenTelemetrySupport

/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
internal struct DefaultResponder: Responder {
    private let router: TrieRouter<CachedRoute>
    private let notFoundResponder: Responder

    private struct CachedRoute {
        let route: Route
        let responder: Responder
    }

    /// Creates a new `ApplicationResponder`
    public init(routes: Routes, middleware: [Middleware] = []) {
        let options = routes.caseInsensitive ?
            Set(arrayLiteral: TrieRouter<CachedRoute>.ConfigurationOption.caseInsensitive) : []
        let router = TrieRouter(CachedRoute.self, options: options)
        
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
        let startTime = DispatchWallTime.now()
        var routeString = request.url.path
        let span: Span

        let response: EventLoopFuture<Response>
        if let cachedRoute = self.getRoute(for: request) {
            routeString = "/\(cachedRoute.route.path.string)"
            span = InstrumentationSystem.tracer.startSpan(
                routeString,
                baggage: request.baggage,
                ofKind: .server,
                at: startTime
            )
            request.baggage = span.baggage
            request.route = cachedRoute.route
            response = cachedRoute.responder.respond(to: request)
        } else {
            span = InstrumentationSystem.tracer.startSpan(
                routeString,
                baggage: request.baggage,
                ofKind: .server,
                at: startTime
            )
            request.baggage = span.baggage
            response = self.notFoundResponder.respond(to: request)
        }

        span.attributes.http.method = request.method.rawValue
        span.attributes.http.flavor = "\(request.version.major).\(request.version.minor)"
        span.attributes.http.target = request.url.path
        span.attributes.http.host = request.headers.first(name: .host)
        span.attributes.http.server.name = request.application.http.server.configuration.hostname
        span.attributes.net.host.port = request.application.http.server.configuration.port
        span.attributes.http.scheme = request.url.scheme
        span.attributes.http.server.route = routeString
        span.attributes.net.peer.ip = request.remoteAddress?.ipAddress
        span.attributes.http.requestContentLength = request.body.data?.readableBytes
        span.attributes.http.userAgent = request.headers.first(name: .userAgent)

        return response.always { result in
            let status: HTTPStatus
            switch result {
            case .success(let response):
                status = response.status
                span.attributes.http.statusCode = Int(response.status.code)
                span.attributes.http.responseContentLength = response.body.buffer?.readableBytes

                if 400 ... 600 ~= response.status.code {
                    span.recordError(Abort(response.status))
                    span.setStatus(SpanStatus(code: .error))
                }
            case .failure(let error):
                span.recordError(error)
                span.setStatus(SpanStatus(code: .error))
                status = .internalServerError
            }
            let endTime = DispatchWallTime.now()
            span.end(at: endTime)
            self.updateMetrics(
                for: request,
                startTime: startTime,
                endTime: endTime,
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
        startTime: DispatchWallTime,
        endTime: DispatchWallTime,
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
        ).recordNanoseconds(Int64(bitPattern: endTime.rawValue) / -1 - Int64(bitPattern: startTime.rawValue) / -1)
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
