#if Compression
public import HTTPTypes

/// Overrides the response compression settings for a route.
///
/// Requires ``ResponseCompressionMiddleware`` earlier in the middleware chain to perform compression.
/// This middleware only sets a preference for the response.
///
/// This is useful when a set of static routes does not need compression, or a set of dynamic routes does.
///
/// Use ``HTTPFields/ResponseCompression/enable`` or ``HTTPFields/ResponseCompression/disable`` to override the configured media type policy for a response. A ``ResponseCompressionMiddleware`` must be registered earlier in the chain to apply the preference.
///
/// To ignore a preference a downstream middleware (ie. closer to the root route than to the original response) may propose in favor of the server defaults, use ``HTTPFields/ResponseCompression/useDefault``.
///
/// - Note: Response compression is only actually used if the client indicates it supports it via an `Accept-Encoding` header.
struct ResponseCompressionOverrideMiddleware: Middleware {
    /// The response compression override to use over the base configuration.
    ///
    /// Overrides are only used when the server's ``ServerConfiguration/ResponseCompressionConfiguration/allowRequestOverrides`` property is enabled, otherwise they are ignored.
    ///
    /// To clear an override set previously in the chain (ie. closer to the root route than to the original response), set ``HTTPFields/ResponseCompression/useDefault``.
    ///
    /// - Note: Middleware that come after this one, or responses with a ``HTTPFields/ResponseCompression`` header, will take priority over the override set here, unless ``shouldForce`` is set to true.
    var responseCompressionOverride: HTTPFields.ResponseCompression

    /// A flag to force the override atop whatever the response or output of middleware that process the response before this one.
    var shouldForce: Bool

    /// Initialize a response compression middleware with an override.
    ///
    /// - Parameters:
    ///   - override: The compression preference to apply if none is already set.
    ///   - shouldForce: Wether to force the compression preference over what the response prefers.
    ///
    /// - SeeAlso: Please see ``responseCompressionOverride`` for more details.
    init(override: HTTPFields.ResponseCompression, force shouldForce: Bool = false) {
        self.responseCompressionOverride = override
        self.shouldForce = shouldForce
    }

    func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        var response = try await next.respond(to: request)
        /// Only set the header if it is unset, and prefer the next responder's header over our own override, as _it_ is overriding ours.
        if response.headers.responseCompression == .unset || shouldForce {
            response.headers.responseCompression = responseCompressionOverride
        }
        return response
    }
}

extension RoutesBuilder {
    /// Override the response compression settings for a route.
    ///
    /// This is useful when a set of static routes does not need compression, or a set of dynamic routes does.
    ///
    /// Use ``HTTPFields/ResponseCompression/enable`` or ``HTTPFields/ResponseCompression/disable`` to override the configured media type policy for a response. A ``ResponseCompressionMiddleware`` must be registered earlier in the chain to apply the preference.
    ///
    /// To ignore a preference a downstream middleware (ie. closer to the root route than to the original response) may propose in favor of the server defaults, use ``HTTPFields/ResponseCompression/useDefault``.
    ///
    /// - Note: Response compression is only actually used if the client indicates it supports it via an `Accept-Encoding` header.
    /// - Note: Setting the override to ``HTTPFields/ResponseCompression/unset`` has no effect here unless `force` is set to true.
    ///
    /// - Parameters:
    ///   - override: The compression preference to apply if none is already set.
    ///   - shouldForce: Wether to force the compression preference over what the response prefers.
    /// - Returns: A route with the specified response compression preferences.
    public func responseCompression(_ override: HTTPFields.ResponseCompression, force shouldForce: Bool = false) -> any RoutesBuilder {
        self.grouped(ResponseCompressionOverrideMiddleware(override: override, force: shouldForce))
    }
}

#endif
