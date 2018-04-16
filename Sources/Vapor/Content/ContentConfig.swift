/// Configures which `Encoder`s and `Decoder`s to use when interacting with data in HTTP messages.
///
///     var contentConfig = ContentConfig.default()
///     contentConfig.use(encoder: JSONEncoder(), for: .json)
///     services.register(contentConfig)
///
/// Each coder is registered to a specific `MediaType`. When _decoding_ content from HTTP messages,
/// the `MediaType` will be specified by the message itself. When _encoding_ content from HTTP messages,
/// the `MediaType` should be specified (`MediaType.json` is usually the assumed default).
///
///     try res.content.encode("hello", as: .plaintext)
///     print(res.mediaType) // .plaintext
///     print(res.http.body) // "hello"
///
/// Most often, these configured coders are used to encode and decode types conforming to `Content`.
/// See the `Content` protocol for more information.
public struct ContentConfig: Service, ServiceType {
    /// See `ServiceType.serviceSupports`
    public static let serviceSupports: [Any.Type] = []

    /// See `ServiceType.makeService`
    public static func makeService(for worker: Container) throws -> ContentConfig {
        return ContentConfig.default()
    }

    /// Represents a yet-to-be-configured object.
    typealias Lazy<T> = (Container) throws -> T

    /// Configured `HTTPMessageEncoder`s.
    private var httpEncoders: [MediaType: Lazy<HTTPMessageEncoder>]

    /// Configured `HTTPMessageDecoder`s.
    private var httpDecoders: [MediaType: Lazy<HTTPMessageDecoder>]

    /// Configured `DataEncoder`s.
    private var dataEncoders: [MediaType: Lazy<DataEncoder>]

    /// Configured `DataDecoder`s.
    private var dataDecoders: [MediaType: Lazy<DataDecoder>]

    /// Create a new content config.
    public init() {
        self.httpEncoders = [:]
        self.httpDecoders = [:]
        self.dataEncoders = [:]
        self.dataDecoders = [:]
    }

    /// Adds an encoder for the specified media type.
    public mutating func use(encoder: HTTPMessageEncoder & DataEncoder, for mediaType: MediaType) {
        use(httpEncoder: encoder, for: mediaType)
        use(dataEncoder: encoder, for: mediaType)
    }

    /// Adds a decoder for the specified media type.
    public mutating func use(decoder: HTTPMessageDecoder & DataDecoder, for mediaType: MediaType) {
        use(httpDecoder: decoder, for: mediaType)
        use(dataDecoder: decoder, for: mediaType)
    }

    /// Adds an encoder for the specified media type.
    public mutating func use<B>(encoder: B.Type, for mediaType: MediaType) where B: HTTPMessageEncoder & DataEncoder {
        use(httpEncoder: encoder, for: mediaType)
        use(dataEncoder: encoder, for: mediaType)
    }

    /// Adds a decoder for the specified media type.
    public mutating func use<B>(decoder: B.Type, for mediaType: MediaType) where B: HTTPMessageDecoder & DataDecoder {
        use(httpDecoder: decoder, for: mediaType)
        use(dataDecoder: decoder, for: mediaType)
    }


    /// Adds an encoder for the specified media type.
    public mutating func use(httpEncoder: HTTPMessageEncoder, for mediaType: MediaType) {
        self.httpEncoders[mediaType] = { container in
            return httpEncoder
        }
    }

    /// Adds a decoder for the specified media type.
    public mutating func use(httpDecoder: HTTPMessageDecoder, for mediaType: MediaType) {
        self.httpDecoders[mediaType] = { container in
            return httpDecoder
        }
    }

    /// Adds an encoder for the specified media type.
    public mutating func use<B>(httpEncoder: B.Type, for mediaType: MediaType) where B: HTTPMessageEncoder {
        self.httpEncoders[mediaType] = { container in
            return try container.make(B.self)
        }
    }

    /// Adds a decoder for the specified media type.
    public mutating func use<B>(httpDecoder: B.Type, for mediaType: MediaType) where B: HTTPMessageDecoder {
        self.httpDecoders[mediaType] = { container in
            return try container.make(B.self)
        }
    }

    /// Adds an encoder for the specified media type.
    public mutating func use(dataEncoder: DataEncoder, for mediaType: MediaType) {
        self.dataEncoders[mediaType] = { container in
            return dataEncoder
        }
    }

    /// Adds a decoder for the specified media type.
    public mutating func use(dataDecoder: DataDecoder, for mediaType: MediaType) {
        self.dataDecoders[mediaType] = { container in
            return dataDecoder
        }
    }

    /// Adds an encoder for the specified media type.
    public mutating func use<D>(dataEncoder: D.Type, for mediaType: MediaType) where D: DataEncoder {
        self.dataEncoders[mediaType] = { container in
            return try container.make(D.self)
        }
    }

    /// Adds a decoder for the specified media type.
    public mutating func use<D>(dataDecoder: D.Type, for mediaType: MediaType) where D: DataDecoder {
        self.dataDecoders[mediaType] = { container in
            return try container.make(D.self)
        }
    }

    /// Converts all of the `Lazy<T>` coders to initialized instances using the supplied container.
    internal func boot(using container: Container) throws -> ContentCoders {
        return try ContentCoders(
            httpEncoders: httpEncoders.mapValues { try $0(container) },
            httpDecoders: httpDecoders.mapValues { try $0(container) },
            dataEncoders: dataEncoders.mapValues { try $0(container) },
            dataDecoders: dataDecoders.mapValues { try $0(container) }
        )
    }
}

/// MARK: Default

extension ContentConfig {
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
        config.use(encoder: PlaintextEncoder(mediaType: .html), for: .html)

        // form-urlencoded
        config.use(encoder: URLEncodedFormEncoder(), for: .urlEncodedForm)
        config.use(decoder: URLEncodedFormDecoder(), for: .urlEncodedForm)

        // form-data, doesn't support `Data{En|De}coder` because a predefined boundary is required
        config.use(httpEncoder: FormDataEncoder(), for: .formData)
        config.use(httpDecoder: FormDataDecoder(), for: .formData)

        return config
    }
}
