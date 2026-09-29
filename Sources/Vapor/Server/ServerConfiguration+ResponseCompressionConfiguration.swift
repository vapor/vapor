#if Compression
extension ServerConfiguration {
    /// Settings applied by ``ResponseCompressionMiddleware``.
    public struct ResponseCompressionConfiguration: Sendable {
        /// The default output buffer capacity used by the compressor.
        public static let defaultInitialByteBufferCapacity = 1024

        /// The response content types eligible for compression. Defaults to known compressible types.
        public var mediaTypes: MediaTypePolicy

        /// The output buffer capacity used by the compressor, bounded internally between 64 bytes and 64 KiB.
        public var initialByteBufferCapacity: Int

        /// Whether route and response preferences may override the media type policy. Defaults to `true`.
        /// Use `app.responseCompression(...)` to set a route preference.
        public var allowRequestOverrides: Bool

        /// Configures response compression. Register ``ResponseCompressionMiddleware`` to apply it.
        /// - Parameters:
        ///   - mediaTypes: Eligible content types. Defaults to known compressible types.
        ///   - initialByteBufferCapacity: Output buffer capacity. Defaults to 1024 bytes.
        ///   - allowRequestOverrides: Whether routes and responses may override the media type policy.
        public init(
            mediaTypes: MediaTypePolicy = .only(.compressible),
            initialByteBufferCapacity: Int = defaultInitialByteBufferCapacity,
            allowRequestOverrides: Bool = true
        ) {
            self.mediaTypes = mediaTypes
            self.initialByteBufferCapacity = initialByteBufferCapacity
            self.allowRequestOverrides = allowRequestOverrides
        }

        /// Selects response content types to compress, subject to client support and HTTP semantics.
        public enum MediaTypePolicy: Sendable {
            /// Compress only matching types. Responses without a content type do not match.
            /// Use `.only(.none)` to require an explicit route or response override.
            case only(HTTPMediaTypeSet)

            /// Compress all types except matching types, including responses without a content type.
            /// Use `.excluding(.incompressible)` to skip known incompressible types, or `.excluding(.none)` for all types.
            case excluding(HTTPMediaTypeSet)

            func contains(_ mediaType: HTTPMediaType?) -> Bool {
                switch self {
                case .only(let types): mediaType.map(types.contains) ?? false
                case .excluding(let types): !(mediaType.map(types.contains) ?? false)
                }
            }
        }
    }
}
#endif
