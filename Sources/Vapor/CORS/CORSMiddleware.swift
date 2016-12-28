import HTTP

/// Middleware that adds support for CORS settings in request responses.
/// For configuration of this middleware please use the `CORSConfiguration` object.
///
/// - Note: Make sure this middleware is inserted before all your error/abort middlewares,
///         so that even the failed request responses contain proper CORS information.
public class CORSMiddleware: Middleware {

    /// Configuration used for populating headers in response for CORS requests.
    public let configuration: CORSConfiguration

    /// Creates a CORS middleware with the specified configuration.
    ///
    /// - Parameter configuration: Configuration used for populating headers in 
    ///                            response for CORS requests.
    public init(configuration: CORSConfiguration = .default) {
        self.configuration = configuration
    }

    /// Creates the CORS middleware from the values contained in the settings config json file.
    ///
    /// - Parameter configuration: The settings configuration.
    /// - Throws: Exception if the `CORSConfiugration` couldn't be parsed out of `Settings.Config`.
    public convenience init(configuration: Settings.Config) throws {
        let configuration = try CORSConfiguration(config: configuration)
        self.init(configuration: configuration)
    }

    public func respond(to request: Request, chainingTo chain: Responder) throws -> Response {
        // Check if it's valid CORS request
        guard request.headers["Origin"] != nil else {
            return try chain.respond(to: request)
        }

        // Determine if the request is pre-flight.
        // If it is, create empty response otherwise get response from the responder chain.
        let response = request.isPreflight ? "".makeResponse() : try chain.respond(to: request)

        // Modify response headers based on CORS settings
        response.headers["Access-Control-Allow-Origin"] = configuration.allowedOrigin.header(forRequest: request)
        response.headers["Access-Control-Allow-Headers"] = configuration.allowedHeaders
        response.headers["Access-Control-Allow-Methods"] = configuration.allowedMethods

        if let exposedHeaders = configuration.exposedHeaders {
            response.headers["Access-Control-Expose-Headers"] = exposedHeaders
        }

        if let cacheExpiration = configuration.cacheExpiration {
            response.headers["Access-Control-Max-Age"] = String(cacheExpiration)
        }

        if configuration.allowCredentials {
            response.headers["Access-Control-Allow-Credentials"] = "true"
        }

        return response
    }
}

extension Request {

    /// Returns `true` if the request is a pre-flight CORS request.
    var isPreflight: Bool {
        return method == .options
            && headers["Access-Control-Request-Method"] != nil
    }
}
