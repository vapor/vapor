extension CORSMiddleware.Configuration {
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
    @available(*, deprecated, message: "exposedHeaders parameter now accepts [HTTPHeaders.Name]")
    public init(
        allowedOrigin: CORSMiddleware.AllowOriginSetting,
        allowedMethods: [HTTPMethod],
        allowedHeaders: [HTTPHeaders.Name],
        allowCredentials: Bool = false,
        cacheExpiration: Int? = 600,
        exposedHeaders: [String]
    ) {
        self.allowedOrigin = allowedOrigin
        self.allowedMethods = allowedMethods.map({ "\($0)" }).joined(separator: ", ")
        self.allowedHeaders = allowedHeaders.map({ $0.description }).joined(separator: ", ")
        self.allowCredentials = allowCredentials
        self.cacheExpiration = cacheExpiration
        self.exposedHeaders = exposedHeaders.joined(separator: ", ")
    }
}
