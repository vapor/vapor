public struct ApplicationResponder: Responder {
    private let router: Router
    
    private let requestsCountLabel: String = "http_requests_total"
    private let requestsTimerLabel: String = "http_request_duration_seconds"
    private let requestsErrorsLabel: String = "http_request_errors_total"

    init(_ router: Router) {
        self.router = router
    }
    
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        let start = DispatchTime.now().uptimeNanoseconds
        let res = router.getRoute(for: request).responder.respond(to: request)
        
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
