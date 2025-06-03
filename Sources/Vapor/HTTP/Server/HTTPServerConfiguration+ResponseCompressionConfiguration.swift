extension HTTPServer.Configuration {
    /// Supported HTTP response compression options.
    public struct ResponseCompressionConfiguration: Sendable {
        /// The default initial byte buffer capacity to use for the compressor if none is specified.
        public static let defaultInitialByteBufferCapacity = 1024
        
        /// Disables compression unconditionally.
        ///
        /// This is useful when you never want any response to be compressed for debugging purposes.
        public static var forceDisabled: Self {
            .disabled(
                initialByteBufferCapacity: defaultInitialByteBufferCapacity,
                allowedTypes: .none,
                allowRequestOverrides: false
            )
        }
        
        /// Disables compression for all content types unless a route overrides the preference. This is the default.
        ///
        /// - SeeAlso: See ``ResponseCompressionMiddleware`` for more information on overriding compression preferences in routes.
        public static var disabled: Self {
            .disabled(
                initialByteBufferCapacity: defaultInitialByteBufferCapacity,
                allowedTypes: .none,
                allowRequestOverrides: true
            )
        }
        
        /// Disables compression by default, but allows easily compressible types such as text, unless a route overrides the preference.
        ///
        /// - SeeAlso: See ``ResponseCompressionMiddleware`` for more information on overriding compression preferences in routes.
        public static var enabledForCompressibleTypes: Self {
            .disabled(
                initialByteBufferCapacity: defaultInitialByteBufferCapacity,
                allowedTypes: .compressible,
                allowRequestOverrides: true
            )
        }
        
        /// Enables compression by default, disallowing already compressed types such as images or video, unless a route overrides the preference.
        ///
        /// - SeeAlso: See ``ResponseCompressionMiddleware`` for more information on overriding compression preferences in routes.
        public static var enabled: Self {
            .enabled(
                initialByteBufferCapacity: defaultInitialByteBufferCapacity,
                disallowedTypes: .incompressible,
                allowRequestOverrides: true
            )
        }
        
        /// Enables compression with custom configuration.
        @available(*, deprecated, renamed: "enabled(initialByteBufferCapacity:disallowedTypes:allowRequestOverrides:)", message: "Renamed to allow for more parameters.")
        @_disfavoredOverload // TODO: Remove this overload in Vapor 5
        public static func enabled(
            initialByteBufferCapacity: Int
        ) -> Self {
            .enabled(
                initialByteBufferCapacity: initialByteBufferCapacity,
                disallowedTypes: .incompressible,
                allowRequestOverrides: true
            )
        }
        
        /// Disables compression by default, but offers options to allow it for the specified types.
        ///
        /// - Parameters:
        ///   - initialByteBufferCapacity: The initial buffer capacity to use when instanciating the compressor.
        ///   - allowedTypes: The types to allow to be compressed. If unspecified, no types will match, thus disabling compression unless explicitly overriden. Specify ``HTTPMediaTypeSet/compressible`` to use a default set of types that compress well.
        ///   - allowRequestOverrides: Allow routes and requests to explicitly enable compression. If unspecified, responses will not be compressed by default unless routes or responses explicitly enable it. See ``ResponseCompressionMiddleware`` for more information.
        /// - Returns: A response compression configuration.
        public static func disabled(
            initialByteBufferCapacity: Int = defaultInitialByteBufferCapacity,
            allowedTypes: HTTPMediaTypeSet = .none,
            allowRequestOverrides: Bool = true
        ) -> Self {
            .init(storage: .disabled(
                initialByteBufferCapacity: initialByteBufferCapacity,
                allowedTypes: allowedTypes,
                allowRequestOverrides: allowRequestOverrides
            ))
        }
        
        /// Enables compression by default, but offers options to disallow it for the specified types.
        ///
        /// - Parameters:
        ///   - initialByteBufferCapacity: The initial buffer capacity to use when instanciating the compressor.
        ///   - disallowedTypes: The types to prevent from being compressed. If unspecified, incompressible types will match, thus disabling compression for media types unless explicitly overriden. Specify ``HTTPMediaTypeSet/none`` to enable compression for all types by default.
        ///   - allowRequestOverrides: Allow routes and requests to explicitly disable compression. If unspecified, responses will be compressed by default unless routes or responses explicitly disable it. See ``ResponseCompressionMiddleware`` for more information.
        /// - Returns: A response compression configuration.
        public static func enabled(
            initialByteBufferCapacity: Int = defaultInitialByteBufferCapacity,
            disallowedTypes: HTTPMediaTypeSet = .incompressible,
            allowRequestOverrides: Bool = true
        ) -> Self {
            .init(storage: .enabled(
                initialByteBufferCapacity: initialByteBufferCapacity,
                disallowedTypes: disallowedTypes,
                allowRequestOverrides: true
            ))
        }
        
        enum Storage {
            case disabled(initialByteBufferCapacity: Int, allowedTypes: HTTPMediaTypeSet, allowRequestOverrides: Bool)
            case enabled(initialByteBufferCapacity: Int, disallowedTypes: HTTPMediaTypeSet, allowRequestOverrides: Bool)
            
            var initialByteBufferCapacity: Int {
                get {
                    switch self {
                    case .disabled(let initialByteBufferCapacity, _, _),
                            .enabled(let initialByteBufferCapacity, _, _):
                        return initialByteBufferCapacity
                    }
                }
                set {
                    switch self {
                    case .disabled(_, let allowedTypes, let allowRequestOverrides):
                        self = .disabled(initialByteBufferCapacity: newValue, allowedTypes: allowedTypes, allowRequestOverrides: allowRequestOverrides)
                    case .enabled(_, let disallowedTypes, let allowRequestOverrides):
                        self = .enabled(initialByteBufferCapacity: newValue, disallowedTypes: disallowedTypes, allowRequestOverrides: allowRequestOverrides)
                    }
                }
            }
            
            var allowRequestOverrides: Bool {
                get {
                    switch self {
                    case .disabled(_, _, let allowRequestOverrides),
                            .enabled(_, _, let allowRequestOverrides):
                        return allowRequestOverrides
                    }
                }
                set {
                    switch self {
                    case .disabled(let initialByteBufferCapacity, let allowedTypes, _):
                        self = .disabled(initialByteBufferCapacity: initialByteBufferCapacity, allowedTypes: allowedTypes, allowRequestOverrides: newValue)
                    case .enabled(let initialByteBufferCapacity, let disallowedTypes, _):
                        self = .enabled(initialByteBufferCapacity: initialByteBufferCapacity, disallowedTypes: disallowedTypes, allowRequestOverrides: newValue)
                    }
                }
            }
        }
        
        var storage: Storage
        
        /// The initial buffer capacity to use when instanciating the compressor.
        public var initialByteBufferCapacity: Int {
            get { storage.initialByteBufferCapacity }
            set { storage.initialByteBufferCapacity = newValue }
        }
        
        /// Allow routes and requests to explicitly override compression.
        ///
        /// - SeeAlso: See ``ResponseCompressionMiddleware`` for more information.
        public var allowRequestOverrides: Bool {
            get { storage.allowRequestOverrides }
            set { storage.allowRequestOverrides = newValue }
        }
    }
    
    @available(*, deprecated, renamed: "ResponseCompressionConfiguration", message: "Renamed to ResponseCompressionConfiguration for clarity.")
    public typealias CompressionConfiguration = ResponseCompressionConfiguration
}
