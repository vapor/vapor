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
            router.register(cached, at: [.constant(route.method.string)] + path)
        }
        self.router = router
        self.notFoundResponder = middleware.makeResponder(chainingTo: NotFoundResponder())
    }

    /// See `Responder`
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        let startTime = DispatchTime.now().uptimeNanoseconds
        let span = InstrumentationSystem.tracer.startSpan("Responder.respond", baggage: request.context.baggage, ofKind: .server)
        self.initiateTracing(for: request, span: span)
        let response: EventLoopFuture<Response>
        let path: String
        if let cachedRoute = self.getRoute(for: request) {
            path = cachedRoute.route.description
            request.route = cachedRoute.route
            response = cachedRoute.responder.respond(to: request)
        } else {
            path = request.url.path
            response = self.notFoundResponder.respond(to: request)
        }
        return response.always { result in
            let status: HTTPStatus
            let err: Error?
            let contentLength: String?
            switch result {
            case .success(let response):
                status = response.status
                err = nil
                contentLength = response.headers.first(name: .contentLength)
            case .failure(let error):
                status = .internalServerError
                err = error
                contentLength = nil
            }
            self.updateMetrics(
                for: request,
                path: path,
                startTime: startTime,
                statusCode: status.code
            )
            self.updateTracing(
                for: request,
                span: span,
                status: status,
                error: err,
                contentLength: contentLength
            )
        }
    }
    
    /// Gets a `Route` from the underlying `TrieRouter`.
    private func getRoute(for request: Request) -> CachedRoute? {
        let pathComponents = request.url.path
            .split(separator: "/")
            .map(String.init)
        
        let method = (request.method == .HEAD) ? .GET : request.method
        return self.router.route(
            path: [method.string] + pathComponents,
            parameters: &request.parameters
        )
    }
    
    private func initiateTracing(
        for request: Request,
        span: Span
    ) {
        span.attributes.http.method = request.method.rawValue
        span.attributes.http.flavor = "\(request.version.major).\(request.version.minor)"
        span.attributes.http.host = request.headers.first(name: .host)
        span.attributes.http.target = request.url.path
        span.attributes.http.scheme = request.url.scheme
        span.attributes.http.userAgent = request.headers.first(name: .userAgent)
        if let remoteAddress = request.remoteAddress {
            span.attributes.net.peerIP = remoteAddress.ipAddress
        }
    }
    
    private func updateTracing(
        for request: Request,
        span: Span,
        status: HTTPStatus,
        error: Error?,
        contentLength: String?
    ) {
        defer { span.end() }
        let status = (error as? AbortError)?.status ?? status
        span.attributes.http.statusCode = Int(status.code)
        span.attributes.http.statusText = status.reasonPhrase
        if let l = contentLength { span.attributes.http.responseContentLength = Int(l) }
        if let e = error { span.recordError(e) }
    }

    /// Records the requests metrics.
    private func updateMetrics(
        for request: Request,
        path: String,
        startTime: UInt64,
        statusCode: UInt
    ) {
        let counterDimensions = [
            ("method", request.method.string),
            ("path", path),
            ("status", statusCode.description),
        ]
        Counter(label: "http_requests_total", dimensions: counterDimensions).increment()
        if statusCode >= 500 {
            Counter(label: "http_request_errors_total", dimensions: counterDimensions).increment()
        }
        Timer(
            label: "http_request_duration_seconds",
            dimensions: [
                ("method", request.method.string),
                ("path", path)
            ],
            preferredDisplayUnit: .seconds
        ).recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
    }
}

private struct NotFoundResponder: Responder {
    func respond(to request: Request) -> EventLoopFuture<Response> {
        request.eventLoop.makeFailedFuture(RouteNotFound())
    }
}

struct RouteNotFound: Error { }

extension RouteNotFound: AbortError {
    static var typeIdentifier: String {
        "Abort"
    }
    
    var status: HTTPResponseStatus {
        .notFound
    }
}

extension RouteNotFound: DebuggableError {
    var logLevel: Logger.Level { 
        .debug
    }
}
