import Dispatch

/// Middleware to track in per-request metrics
///
/// This middleware is "backend-agnostic" and can be used with any `swift-metrics`-compatible
/// implementation.
/// Use `MetricsSystem.bootstrap(_:)` to bootstrap a Metrics Provider.
public final class MetricsMiddleware: Middleware {
    let requestsCountLabel: String
    let requestsTimerLabel: String
    let requestsErrorsLabel: String
    
    public init(
        requestsCountLabel: String = "http_requests_total",
        requestsTimerLabel: String = "http_request_duration_seconds",
        requestsErrorsLabel: String = "http_request_errors_total"
    ) {
        self.requestsCountLabel =  requestsCountLabel
        self.requestsTimerLabel = requestsTimerLabel
        self.requestsErrorsLabel = requestsErrorsLabel
    }
    
    /// See `Middleware`.
    public func respond(to request: Request, on route: Route, chainingTo next: Responder) -> EventLoopFuture<Response> {
        let start = DispatchTime.now().uptimeNanoseconds
        
        let res = next.respond(to: request, on: route)
        
        res.whenComplete { result in
            switch result {
            case .success(let res):
                self.updateMetrics(for: request, label: self.requestsCountLabel, start: start, status: res.status.code)
            case .failure(_):
                self.updateMetrics(for: request, label: self.requestsErrorsLabel, start: start)
            }
        }
        
        return res
    }
    
    /// Records the requests metrics.
    private func updateMetrics(for request: Request, label: String, start: UInt64, status: UInt? = nil) {
        var counterDimensions = [
            ("method", request.method.string),
            ("path", request.url.path)
        ]
        if let status = status {
            counterDimensions.append(("status", "\(status)"))
        }
        let timerDimensions = [
            ("method", request.method.string),
            ("path", request.url.path)
        ]
        Counter(label: label, dimensions: counterDimensions).increment()
        let time = DispatchTime.now().uptimeNanoseconds - start
        Timer(label: requestsTimerLabel, dimensions: timerDimensions, preferredDisplayUnit: .seconds).recordNanoseconds(time)
    }
}
