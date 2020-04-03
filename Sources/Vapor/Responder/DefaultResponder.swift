import Metrics

/// Vapor's main `Responder` type. Combines configured middleware + router to create a responder.
internal struct DefaultResponder: Responder {
    private let router: TrieRouter<Route>
    private let notFoundRoute: Route

    private let requestsCountLabel: String = "http_requests_total"
    private let requestsTimerLabel: String = "http_request_duration_seconds"
    private let requestsErrorsLabel: String = "http_request_errors_total"

    /// Creates a new `ApplicationResponder`
    public init(routes: Routes, middleware: [Middleware] = []) {
        // We create & store this at init time to not impact performance later on in the application.
        // This `Route` is used to return a 404 response, instead of an error.
        let notFoundResponder = middleware.makeResponder(chainingTo: BasicResponder(closure: { _ in throw Abort(.notFound) }))
        self.notFoundRoute = Route(method: .GET, path: [], responder: notFoundResponder, requestType: Request.self, responseType: Response.self)
        let router = TrieRouter(Route.self)
        for route in routes.all {
            // Make a copy of the route to cache middleware chaining.
            let copy = Route(
                method: route.method,
                path: route.path,
                responder: middleware.makeResponder(chainingTo: route.responder),
                requestType: route.requestType,
                responseType: route.responseType
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
            router.register(copy, at: [.constant(route.method.string)] + path)
        }
        self.router = router
    }

    /// See `Responder`
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        request.logger.info("\(request.method) \(request.url.path)")
        let start = DispatchTime.now().uptimeNanoseconds
        let res = self.getRoute(for: request).responder.respond(to: request)
        
        res.whenComplete { result in
            guard let route = request.route else { return }
            switch result {
            case .success(let res):
                self.updateMetrics(for: request, on: route, label: self.requestsCountLabel, start: start, status: res.status.code)
            case .failure(_):
                self.updateMetrics(for: request, on: route, label: self.requestsErrorsLabel, start: start)
            }
        }
        
        return res
    }
    
    /// Gets a `Route` from the underlying `TrieRouter`.
    private func getRoute(for request: Request) -> Route {
        let pathComponents = request.url.path
            .split(separator: "/")
            .map(String.init)
        
        let method = (request.method == .HEAD) ? .GET : request.method
        
        guard let route = self.router.route(
            path: [method.string] + pathComponents,
            parameters: &request.parameters
        ) else {
            return notFoundRoute
        }
        request.route = route
        return route
    }

    /// Records the requests metrics.
    private func updateMetrics(for request: Request, on route: Route, label: String, start: UInt64, status: UInt? = nil) {
        var counterDimensions = [
            ("method", request.method.string),
            ("path", route.description)
        ]
        if let status = status {
            counterDimensions.append(("status", "\(status)"))
        }
        let timerDimensions = [
            ("method", request.method.string),
            ("path", route.description)
        ]
        Counter(label: label, dimensions: counterDimensions).increment()
        let time = DispatchTime.now().uptimeNanoseconds - start
        Timer(label: requestsTimerLabel, dimensions: timerDimensions, preferredDisplayUnit: .seconds).recordNanoseconds(time)
    }
}
