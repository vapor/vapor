/// Configures which `Encoder`s and `Decoder`s to use when interacting with data in HTTP messages.
///
///     var contentConfig = ContentConfig()
///     contentConfig.use(encoder: JSONEncoder(), for: .json)
///     services.register(contentConfig)
///
/// Each coder is registered to a specific `MediaType`. When _decoding_ content from HTTP messages,
/// the `MediaType` will be specified by the message itself. When _encoding_ content from HTTP messages,
/// the `MediaType` should be specified (`MediaType.json` is usually the assumed default).
///
///     try res.content.encode("hello", as: .plainText)
///     print(res.mediaType) // .plainText
///     print(res.http.body) // "hello"
///
/// Most often, these configured coders are used to encode and decode types conforming to `Content`.
/// See the `Content` protocol for more information.
public struct HTTPContentConfig {
    // MARK: Default
    
    public static var global: HTTPContentConfig = .default()

    /// Creates a `ContentConfig` containing all of Vapor's default coders.
    ///
    ///     var contentConfig = ContentConfig.default()
    ///     // add or replace coders
    ///     services.register(contentConfig)
    ///
    public static func `default`() -> ContentConfig {
        var config = ContentConfig()

        // json
        do {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            if #available(macOS 10.12, *) {
                encoder.dateEncodingStrategy = .iso8601
                decoder.dateDecodingStrategy = .iso8601
            } else {
                ERROR("macOS SDK < 10.12 detected, no ISO-8601 JSON support")
            }
            config.use(encoder: encoder, for: .json)
            config.use(decoder: decoder, for: .json)
        }

        // data
        config.use(encoder: PlaintextEncoder(), for: .plainText)
        config.use(encoder: PlaintextEncoder(.html), for: .html)

        #warning("TODO: update url encoded / form data encoders")
//        // form-urlencoded
//        config.use(encoder: URLEncodedFormEncoder(), for: .urlEncodedForm)
//        config.use(decoder: URLEncodedFormDecoder(), for: .urlEncodedForm)
//
//        // form-data, doesn't support `Data{En|De}coder` because a predefined boundary is required
//        config.use(encoder: FormDataEncoder(), for: .formData)
//        config.use(decoder: FormDataDecoder(), for: .formData)

        return config
    }

    // MARK: Service

    /// Configured `HTTPMessageEncoder`s.
    private var encoders: [HTTPMediaType: HTTPMessageEncoder]

    /// Configured `HTTPMessageDecoder`s.
    private var decoders: [HTTPMediaType: HTTPMessageDecoder]

    // MARK: Init

    /// Create a new, empty `ContentConfig`.
    public init() {
        self.encoders = [:]
        self.decoders = [:]
    }

    /// Adds an `HTTPMessageEncoder` for the specified `MediaType`.
    ///
    ///     contentConfig.use(httpEncoder: JSONEncoder(), for: .json)
    ///
    /// - parameters:
    ///     - httpEncoder: `HTTPMessageEncoder` to use.
    ///     - HTTPMediaType: `HTTPMessageEncoder` will be used to encode this `MediaType`.
    public mutating func use(encoder: HTTPMessageEncoder, for mediaType: HTTPMediaType) {
        self.encoders[mediaType] = encoder
    }

    /// Adds an `HTTPMessageDecoder` for the specified `MediaType`.
    ///
    ///     contentConfig.use(httpDecoder: JSONDecoder(), for: .json)
    ///
    /// - parameters:
    ///     - httpDecoder: `HTTPMessageDecoder` to use.
    ///     - HTTPMediaType: `HTTPMessageDecoder` will be used to decode this `MediaType`.
    public mutating func use(decoder: HTTPMessageDecoder, for mediaType: HTTPMediaType) {
        self.decoders[mediaType] = decoder
    }
    
    // MARK: Resolve
    
    
    /// Returns an `HTTPMessageEncoder` for the specified `MediaType` or throws an error.
    ///
    ///     let coder = try coders.requireHTTPEncoder(for: .json)
    ///
    /// - parameters:
    ///     - HTTPMediaType: An encoder for this `MediaType` will be returned.
    public func requireEncoder(for mediaType: HTTPMediaType) throws -> HTTPMessageEncoder {
        guard let encoder = self.encoders[mediaType] else {
            throw Abort(.unsupportedMediaType, identifier: "httpEncoder", suggestedFixes: [
                "Register an `HTTPMessageEncoder` using `HTTPContentConfig`.",
                "Use one of the encoding methods that accepts a custom encoder."
            ])
        }
        
        return encoder
    }
    
    /// Returns a `HTTPMessageDecoder` for the specified `MediaType` or throws an error.
    ///
    ///     let coder = try coders.requireHTTPDecoder(for: .json)
    ///
    /// - parameters:
    ///     - HTTPMediaType: A decoder for this `MediaType` will be returned.
    public func requireDecoder(for mediaType: HTTPMediaType) throws -> HTTPMessageDecoder {
        guard let decoder = self.decoders[mediaType] else {
            throw Abort(.unsupportedMediaType, identifier: "httpDecoder", suggestedFixes: [
                "Register an `HTTPMessageDecoder` using `HTTPContentConfig`.",
                "Use one of the decoding methods that accepts a custom decoder."
            ])
        }
        
        return decoder
    }
}
