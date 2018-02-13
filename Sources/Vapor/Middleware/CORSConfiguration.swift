import HTTP

extension CORSMiddleware {
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
            case .originBased: return request.http.headers[.origin] ?? ""
            case .all: return "*"
            case .custom(let string):
                guard let origin = request.http.headers[.origin] else {
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
        public static let `default` = Configuration(
            allowedOrigin: .originBased,
            allowedMethods: [.get, .post, .put, .options, .delete, .patch],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
        )
        
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
        /// - Parameters:
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
            self.allowedMethods = allowedMethods.map({ $0.string }).joined(separator: ", ")
            self.allowedHeaders = allowedHeaders.map({ $0.description }).joined(separator: ", ")
            self.allowCredentials = allowCredentials
            self.cacheExpiration = cacheExpiration
            self.exposedHeaders = exposedHeaders?.joined(separator: ", ")
        }
    }
}
