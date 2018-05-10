/// Middleware that adds support for CORS settings in request responses.
/// For configuration of this middleware please use the `CORSMiddleware.Configuration` object.
///
/// - note: Make sure this middleware is inserted before all your error/abort middlewares,
///         so that even the failed request responses contain proper CORS information.
public final class CORSMiddleware: Middleware {
    /// Option for the allow origin header in responses for CORS requests.
    ///
    /// - none: Disallows any origin.
    /// - originBased: Uses value of the origin header in the request.
    /// - all: Uses wildcard to allow any origin.
    /// - custom: Uses custom string provided as an associated value.
    public enum AllowOriginSetting {
        /// Disallow any origin.
        case none

        /// Uses value of the origin header in the request.
        case originBased

        /// Uses wildcard to allow any origin.
        case all

        /// Uses custom string provided as an associated value.
        case custom(String)

        /// Creates the header string depending on the case of self.
        ///
        /// - Parameter request: Request for which the allow origin header should be created.
        /// - Returns: Header string to be used in response for allowed origin.
        public func header(forRequest request: Request) -> String {
            switch self {
            case .none: return ""
            case .originBased: return request.http.headers[.origin].first ?? ""
            case .all: return "*"
            case .custom(let string):
                guard let origin = request.http.headers[.origin].first else {
                    return string
                }
                return string.contains(origin) ? origin : string
            }
        }
    }

    /// Configuration used for populating headers in response for CORS requests.
    public struct Configuration {
        /// Default CORS configuration.
        ///
        /// - Allow Origin: Based on request's `Origin` value.
        /// - Allow Methods: `GET`, `POST`, `PUT`, `OPTIONS`, `DELETE`, `PATCH`
        /// - Allow Headers: `Accept`, `Authorization`, `Content-Type`, `Origin`, `X-Requested-With`
        public static func `default`() -> Configuration {
            return .init(
                allowedOrigin: .originBased,
                allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
                allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
            )
        }

        /// Setting that controls which origin values are allowed.
        public let allowedOrigin: AllowOriginSetting

        /// Header string containing methods that are allowed for a CORS request response.
        public let allowedMethods: String

        /// Header string containing headers that are allowed in a response for CORS request.
        public let allowedHeaders: String

        /// If set to yes, cookies and other credentials will be sent in the response for CORS request.
        public let allowCredentials: Bool

        /// Optionally sets expiration of the cached pre-flight request. Value is in seconds.
        public let cacheExpiration: Int?

        /// Headers exposed in the response of pre-flight request.
        public let exposedHeaders: String?

        /// Instantiate a CORSConfiguration struct that can be used to create a `CORSConfiguration`
        /// middleware for adding support for CORS in your responses.
        ///
        /// - parameters:
        ///   - allowedOrigin: Setting that controls which origin values are allowed.
        ///   - allowedMethods: Methods that are allowed for a CORS request response.
        ///   - allowedHeaders: Headers that are allowed in a response for CORS request.
        ///   - allowCredentials: If cookies and other credentials will be sent in the response.
        ///   - cacheExpiration: Optionally sets expiration of the cached pre-flight request in seconds.
        ///   - exposedHeaders: Headers exposed in the response of pre-flight request.
        public init(
            allowedOrigin: AllowOriginSetting,
            allowedMethods: [HTTPMethod],
            allowedHeaders: [HTTPHeaderName],
            allowCredentials: Bool = false,
            cacheExpiration: Int? = 600,
            exposedHeaders: [String]? = nil
        ) {
            self.allowedOrigin = allowedOrigin
            self.allowedMethods = allowedMethods.map({ "\($0)" }).joined(separator: ", ")
            self.allowedHeaders = allowedHeaders.map({ $0.description }).joined(separator: ", ")
            self.allowCredentials = allowCredentials
            self.cacheExpiration = cacheExpiration
            self.exposedHeaders = exposedHeaders?.joined(separator: ", ")
        }
    }

    /// Configuration used for populating headers in response for CORS requests.
    public let configuration: Configuration
    
    /// Creates a CORS middleware with the specified configuration.
    ///
    /// - parameters:
    ///     - configuration: Configuration used for populating headers in
    ///                      response for CORS requests.
    public init(configuration: Configuration = .default()) {
        self.configuration = configuration
    }

    /// See `Middleware`.
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        // Check if it's valid CORS request
        guard request.http.headers[.origin].first != nil else {
            return try next.respond(to: request)
        }
        
        // Determine if the request is pre-flight.
        // If it is, create empty response otherwise get response from the responder chain.
        let response = request.isPreflight
            ? request.eventLoop.newSucceededFuture(result: request.response())
            : try next.respond(to: request)
        
        return response.map { response in
            // Modify response headers based on CORS settings
            response.http.headers.replaceOrAdd(name: .accessControlAllowOrigin, value: self.configuration.allowedOrigin.header(forRequest: request))
            response.http.headers.replaceOrAdd(name: .accessControlAllowHeaders, value: self.configuration.allowedHeaders)
            response.http.headers.replaceOrAdd(name: .accessControlAllowMethods, value: self.configuration.allowedMethods)
            
            if let exposedHeaders = self.configuration.exposedHeaders {
                response.http.headers.replaceOrAdd(name: .accessControlExpose, value: exposedHeaders)
            }
            
            if let cacheExpiration = self.configuration.cacheExpiration {
                response.http.headers.replaceOrAdd(name: .accessControlMaxAge, value: String(cacheExpiration))
            }
            
            if self.configuration.allowCredentials {
                response.http.headers.replaceOrAdd(name: .accessControlAllowCredentials, value: "true")
            }
            
            return response
        }
    }
}

// MARK: Private

private extension Request {
    /// Returns `true` if the request is a pre-flight CORS request.
    var isPreflight: Bool {
        return http.method == .OPTIONS && http.headers[.accessControlRequestMethod].first != nil
    }
}

