import HTTPTypes
import Tracing

/// Creates a trace and metadata for every request
///
/// See https://opentelemetry.io/docs/specs/semconv/http/http-spans/
public final class TracingMiddleware: Middleware {
    private let setCustomAttributes: @Sendable (inout SpanAttributes, Request) -> Void
    
    /// Create a TracingMiddleware
    public init() {
        self.setCustomAttributes = { _, _ in }
    }
    
    /// Create a TracingMiddleware
    /// - Parameter setCustomAttributes: Closure that allows setting custom span attributes for a particular request. A custom span attribute could be extracted from a request
    /// header, for example. This closure is called during span creation on every request, so should be lightweight.
    public init(
        setCustomAttributes: @escaping @Sendable (inout SpanAttributes, Request) -> Void
    ) {
        self.setCustomAttributes = setCustomAttributes
    }
    
    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        var parentContext = ServiceContext.current ?? ServiceContext.topLevel
        InstrumentationSystem.instrument.extract(request.headers, into: &parentContext, using: HTTPHeadersExtractor())
        
        return try await withSpan(
            // Name: https://opentelemetry.io/docs/specs/semconv/http/http-spans/#name
            request.route?.description ?? "vapor_route_undefined",
            context: parentContext,
            ofKind: .server
        ) { span in            
            // Attributes: https://opentelemetry.io/docs/specs/semconv/http/http-spans/#http-server-semantic-conventions
            span.updateAttributes { attributes in
                // Required
                attributes["http.request.method"] = request.method.rawValue
                attributes["url.path"] = request.url.path
                attributes["url.scheme"] = request.url.scheme
                
                // Conditionally required
                if let route = request.route {
                    attributes["http.route"] = "/" + route.path.map { "\($0)" }.joined(separator: "/")
                }
                
                attributes["network.protocol.name"] = "http"
                let address = request.application.sharedNewAddress.withLockedValue({ $0 })
                switch address {
                case .v4:
                    fallthrough
                case .v6:
                    attributes["server.address"] = address?.ipAddress
                    attributes["server.port"] = address?.port
                case .unixDomainSocket:
                    attributes["server.address"] = address?.description
                case .none:
                    break
                }
                attributes["url.query"] = request.url.query
                
                // Recommended
                attributes["client.address"] = request.peerAddress?.ipAddress
                attributes["network.peer.address"] = request.remoteAddress?.ipAddress
                attributes["network.peer.port"] = request.remoteAddress?.port
                attributes["network.protocol.version"] = "\(request.version.major).\(request.version.minor)"
                attributes["user_agent.original"] = request.headers[.userAgent]
                
                // Custom defined
                setCustomAttributes(&attributes, request)
            }
            let response = try await next.respond(to: request)
            
            span.updateAttributes { attributes in
                // Conditionally required
                attributes["http.response.status_code"] = Int(response.status.code)
            }
            
            // Status: https://opentelemetry.io/docs/specs/semconv/http/http-spans/#status
            if 500 <= response.status.code && response.status.code < 600 {
                span.setStatus(.init(code: .error))
            }
            
            return response
        }
    }
}

// Allows backends to extract information from the request headers. For example, in OTel W3C, this allows frontend/backend
// correlation using the `traceparent` and `tracestate` headers. For more information, see
// https://swiftpackageindex.com/apple/swift-distributed-tracing/main/documentation/tracing/instrumentyourlibrary#Handling-inbound-requests
private struct HTTPHeadersExtractor: Extractor {
    func extract(key name: String, from headers: HTTPFields) -> String? {
        guard let headerName = HTTPField.Name(name) else {
            return nil
        }
        let headerValue = headers[values: headerName]
        if headerValue.isEmpty {
            return nil
        } else {
            return headerValue.joined(separator: ";")
        }
    }
}
