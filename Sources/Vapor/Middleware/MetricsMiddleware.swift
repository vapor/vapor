import Metrics

/// Creates metrics for every request
///
/// See https://opentelemetry.io/docs/specs/semconv/http/http-metrics/
public final class MetricsMiddleware: AsyncMiddleware {
    
    public init() {}
    
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let start = DispatchTime.now().uptimeNanoseconds
        
        // Attributes: https://opentelemetry.io/docs/specs/semconv/http/http-spans/#http-server-semantic-conventions
        let httpRequestMethod = request.method.rawValue
        print(request.url)
        let urlScheme = request.headers.forwarded.first?.proto ?? request.headers[.xForwardedProto].first ?? request.url.scheme ?? "undefined"
        let httpRoute: String
        if let route = request.route {
            httpRoute = "/" + route.path.map { "\($0)" }.joined(separator: "/")
        } else {
            httpRoute = "vapor_route_undefined"
        }
        let networkProtocolName = "http"
        let networkProtocolVersion = "\(request.version.major).\(request.version.minor)"
        
        // http.server.active_requests
        // https://opentelemetry.io/docs/specs/semconv/http/http-metrics/#metric-httpserveractive_requests
        let httpServerActiveRequests = Meter(
            label: "http.server.active_requests",
            dimensions: [
                // Required
                ("http.request.method", httpRequestMethod),
                ("url.scheme", urlScheme),
            ]
        )
        httpServerActiveRequests.increment()
        defer {
            httpServerActiveRequests.decrement()
        }
        
        let responseOrError: ResponseOrError
        var errorType = "undefined"
        var httpResponseStatusCode = "undefined"
        do {
            let response = try await next.respond(to: request)
            responseOrError = .response(response)
            httpResponseStatusCode = response.status.code.description
        } catch {
            responseOrError = .error(error)
            errorType = "\(type(of: error))"
        }
        
        // http.server.request.body.size
        // https://opentelemetry.io/docs/specs/semconv/http/http-metrics/#metric-httpserverrequestbodysize
        Recorder(
            label: "http.server.request.body.size",
            dimensions: [
                // Required
                ("http.request.method", httpRequestMethod),
                ("url.scheme", urlScheme),
                
                // Conditionally Required
                ("error.type", errorType),
                ("http.response.status_code", httpResponseStatusCode),
                ("http.route", httpRoute),
                ("network.protocol.name", networkProtocolName),
                
                // Recommended
                ("network.protocol.version", networkProtocolVersion),
            ]
        ).record(request.body.data?.readableBytes ?? 0)
        
        // http.server.request.duration
        // https://opentelemetry.io/docs/specs/semconv/http/http-metrics/#metric-httpserverrequestduration
        Timer(
            label: "http.server.request.duration",
            dimensions: [
                // Required
                ("http.request.method", httpRequestMethod),
                ("url.scheme", urlScheme),
                
                // Conditionally Required
                ("error.type", errorType),
                ("http.response.status_code", httpResponseStatusCode),
                ("http.route", httpRoute),
                ("network.protocol.name", networkProtocolName),
                
                // Recommended
                ("network.protocol.version", networkProtocolVersion),
            ]
        ).recordNanoseconds(DispatchTime.now().uptimeNanoseconds - start)
        
        switch responseOrError {
        case .error(let error):
            throw error
        case .response(let response):
            
            // http.server.response.body.size
            // https://opentelemetry.io/docs/specs/semconv/http/http-metrics/#metric-httpserverresponsebodysize
            Recorder(
                label: "http.server.response.body.size",
                dimensions: [
                    // Required
                    ("http.request.method", httpRequestMethod),
                    ("url.scheme", urlScheme),
                    
                    // Conditionally Required
                    ("error.type", errorType),
                    ("http.response.status_code", httpResponseStatusCode),
                    ("http.route", httpRoute),
                    ("network.protocol.name", networkProtocolName),
                    
                    // Recommended
                    ("network.protocol.version", networkProtocolVersion),
                ]
            ).record(response.body.count)
            return response
        }
    }
}

fileprivate enum ResponseOrError {
    case response(Response)
    case error(Error)
}
