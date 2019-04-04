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
public struct ContentConfiguration {
    public static var global: ContentConfiguration = .default()
    
    /// Creates a `ContentConfig` containing all of Vapor's default coders.
    ///
    ///     var contentConfig = ContentConfig.default()
    ///     // add or replace coders
    ///     services.register(contentConfig)
    ///
    public static func `default`() -> ContentConfiguration {
        var config = ContentConfiguration()
        
        // json
        do {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            if #available(macOS 10.12, *) {
                encoder.dateEncodingStrategy = .iso8601
                decoder.dateDecodingStrategy = .iso8601
            } else {
                // macOS SDK < 10.12 detected, no ISO-8601 JSON support
            }
            config.use(encoder: encoder, for: .json)
            config.use(decoder: decoder, for: .json)
        }
        
        // data
        config.use(encoder: PlaintextEncoder(), for: .plainText)
        config.use(encoder: PlaintextEncoder(.html), for: .html)
        
        // form-urlencoded
        config.use(encoder: URLEncodedFormEncoder(), for: .urlEncodedForm)
        config.use(decoder: URLEncodedFormDecoder(), for: .urlEncodedForm)
        config.use(urlEncoder: URLEncodedFormEncoder())
        config.use(urlDecoder: URLEncodedFormDecoder())
        
        // form-data
        config.use(encoder: FormDataEncoder(), for: .formData)
        config.use(decoder: FormDataDecoder(), for: .formData)
        
        return config
    }
    
    /// Configured `ContentEncoder`s.
    private var encoders: [HTTPMediaType: ResponseEncoder]
    
    /// Configured `ContentDecoder`s.
    private var decoders: [HTTPMediaType: RequestDecoder]
    
    private var urlEncoder: URLContentEncoder?
    
    private var urlDecoder: URLContentDecoder?
    
    // MARK: Init
    
    /// Create a new, empty `ContentConfig`.
    public init() {
        self.encoders = [:]
        self.decoders = [:]
    }
    
    /// Adds an `ContentEncoder` for the specified `HTTPMediaType`.
    ///
    ///     contentConfig.use(encoder: JSONEncoder(), for: .json)
    ///
    /// - parameters:
    ///     - encoder: `ContentEncoder` to use.
    ///     - mediaType: `ContentEncoder` will be used to encode this `HTTPMediaType`.
    public mutating func use(encoder: ResponseEncoder, for mediaType: HTTPMediaType) {
        self.encoders[mediaType] = encoder
    }
    
    /// Adds a `ContentDecoder` for the specified `HTTPMediaType`.
    ///
    ///     contentConfig.use(decoder: JSONDecoder(), for: .json)
    ///
    /// - parameters:
    ///     - decoder: `ContentDecoder` to use.
    ///     - mediaType: `ContentDecoder` will be used to decode this `HTTPMediaType`.
    public mutating func use(decoder: RequestDecoder, for mediaType: HTTPMediaType) {
        self.decoders[mediaType] = decoder
    }
    

    public mutating func use(urlEncoder: URLContentEncoder) {
        self.urlEncoder = urlEncoder
    }
    

    public mutating func use(urlDecoder: URLContentDecoder) {
        self.urlDecoder = urlDecoder
    }
    
    // MARK: Resolve
    
    /// Returns an `HTTPMessageEncoder` for the specified `MediaType` or throws an error.
    ///
    ///     let coder = try coders.requireHTTPEncoder(for: .json)
    ///
    /// - parameters:
    ///     - HTTPMediaType: An encoder for this `MediaType` will be returned.
    public func requireEncoder(for mediaType: HTTPMediaType) throws -> ResponseEncoder {
        guard let encoder = self.encoders[mediaType] else {
            throw Abort(.unsupportedMediaType, identifier: "httpEncoder")
        }
        
        return encoder
    }
    
    /// Returns a `HTTPMessageDecoder` for the specified `MediaType` or throws an error.
    ///
    ///     let coder = try coders.requireHTTPDecoder(for: .json)
    ///
    /// - parameters:
    ///     - HTTPMediaType: A decoder for this `MediaType` will be returned.
    public func requireDecoder(for mediaType: HTTPMediaType) throws -> RequestDecoder {
        guard let decoder = self.decoders[mediaType] else {
            throw Abort(.unsupportedMediaType, identifier: "httpDecoder")
        }
        
        return decoder
    }
    
    
    /// Returns an `HTTPMessageEncoder` for the specified `MediaType` or throws an error.
    ///
    ///     let coder = try coders.requireHTTPEncoder(for: .json)
    ///
    /// - parameters:
    ///     - HTTPMediaType: An encoder for this `MediaType` will be returned.
    public func requireURLEncoder() throws -> URLContentEncoder {
        guard let encoder = self.urlEncoder else {
            throw Abort(.unsupportedMediaType, identifier: "urlEncoder")
        }
        
        return encoder
    }
    
    /// Returns a `HTTPMessageDecoder` for the specified `MediaType` or throws an error.
    ///
    ///     let coder = try coders.requireHTTPDecoder(for: .json)
    ///
    /// - parameters:
    ///     - HTTPMediaType: A decoder for this `MediaType` will be returned.
    public func requireURLDecoder() throws -> URLContentDecoder {
        guard let decoder = self.urlDecoder else {
            throw Abort(.unsupportedMediaType, identifier: "urlDecoder")
        }
        
        return decoder
    }
}

