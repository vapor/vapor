#if Compression
import Algorithms
import HTTPTypes
import Synchronization

extension Application {
    /// Creates request decompression middleware using the current ``serverConfiguration`` settings.
    ///
    /// Configure the settings before creating the middleware, then register it before middleware that reads bodies:
    ///
    ///     app.middleware.use(app.makeRequestDecompressionMiddleware())
    public func makeRequestDecompressionMiddleware() -> RequestDecompressionMiddleware {
        RequestDecompressionMiddleware(configuration: self.serverConfiguration.requestDecompression)
    }
}

/// Lazily decompresses gzip and deflate request bodies.
///
/// Register this middleware before any middleware that reads request bodies, and after error middleware
/// so decoding errors can be turned into responses. The default maximum expansion ratio is 25:1.
/// Use ``Application/makeRequestDecompressionMiddleware()`` to apply the application's server settings.
/// Request decompression is only enabled for routes whose middleware chain contains this middleware.
public struct RequestDecompressionMiddleware: Middleware {
    private let configuration: ServerConfiguration.RequestDecompressionConfiguration

    /// Creates middleware with a copy of the supplied decompression settings.
    /// - Parameter configuration: Request decompression settings. Defaults to a 25:1 expansion limit.
    public init(configuration: ServerConfiguration.RequestDecompressionConfiguration = .init()) {
        self.configuration = configuration
    }

    public func respond(to request: Request, chainingTo next: any Responder) async throws -> Response {
        var request = request
        if let encoding = request.headers[.contentEncoding]?.trimming(while: { $0 == " " || $0 == "\t" }),
            let coding = HTTPBodyCodec.Coding(rawValue: encoding.lowercased())
        {
            let source = request.bodyStorage.storage.withLock { storage in
                switch storage {
                case .stream(let stream): stream
                case .collected(let data): RequestBodyStream(collected: data)
                case .none: RequestBodyStream(collected: nil)
                }
            }
            let decoded = try RequestBodyStream(decompressing: source, coding: coding, limit: self.configuration.limit)
            request.bodyStorage.storage.withLock { $0 = .stream(decoded) }
            // These describe the wire representation, not the body handlers now see. In particular,
            // collection must enforce route limits against decoded bytes rather than compressed length.
            request.headers[.contentEncoding] = nil
            request.headers[.contentLength] = nil
        }

        return try await next.respond(to: request)
    }
}
#endif
