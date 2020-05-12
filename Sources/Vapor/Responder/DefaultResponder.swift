import Metrics

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
        let options = routes.caseInsenstive ?
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
        request.logger.info("\(request.method) \(request.url.path)")
        let startTime = DispatchTime.now().uptimeNanoseconds
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
        response.whenComplete { result in
            let status: HTTPStatus
            switch result {
            case .success(let response):
                status = response.status
            case .failure:
                status = .internalServerError
            }
            self.updateMetrics(
                for: request,
                path: path,
                startTime: startTime,
                statusCode: status.code
            )
        }
        return response
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
        request.eventLoop.makeFailedFuture(Abort(.notFound))
    }
}
