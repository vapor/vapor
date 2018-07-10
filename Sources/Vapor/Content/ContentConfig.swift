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
public struct ContentConfig: Service, ServiceType {
    // MARK: Default

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

        // form-urlencoded
        config.use(encoder: URLEncodedFormEncoder(), for: .urlEncodedForm)
        config.use(decoder: URLEncodedFormDecoder(), for: .urlEncodedForm)

        // form-data, doesn't support `Data{En|De}coder` because a predefined boundary is required
        config.use(httpEncoder: FormDataEncoder(), for: .formData)
        config.use(httpDecoder: FormDataDecoder(), for: .formData)

        return config
    }

    // MARK: Service

    /// See `ServiceType`.
    public static func makeService(for worker: Container) throws -> ContentConfig {
        return ContentConfig.default()
    }

    /// Represents a yet-to-be-configured coder.
    private typealias Lazy<T> = (Container) throws -> T

    /// Configured `HTTPMessageEncoder`s.
    private var httpEncoders: [MediaType: Lazy<HTTPMessageEncoder>]

    /// Configured `HTTPMessageDecoder`s.
    private var httpDecoders: [MediaType: Lazy<HTTPMessageDecoder>]

    /// Configured `DataEncoder`s.
    private var dataEncoders: [MediaType: Lazy<DataEncoder>]

    /// Configured `DataDecoder`s.
    private var dataDecoders: [MediaType: Lazy<DataDecoder>]

    // MARK: Init

    /// Create a new, empty `ContentConfig`.
    public init() {
        self.httpEncoders = [:]
        self.httpDecoders = [:]
        self.dataEncoders = [:]
        self.dataDecoders = [:]
    }

    // MARK: Message & Data

    /// Adds an `HTTPMessage` and `DataEncoder` for the specified `MediaType`.
    ///
    ///     contentConfig.use(encoder: JSONEncoder(), for: .json)
    ///
    /// - parameters:
    ///     - encoder: `Encoder` to use.
    ///     - mediaType: `Encoder` will be used to encode this `MediaType`.
    public mutating func use(encoder: HTTPMessageEncoder & DataEncoder, for mediaType: MediaType) {
        use(httpEncoder: encoder, for: mediaType)
        use(dataEncoder: encoder, for: mediaType)
    }

    /// Adds an `HTTPMessage` and `DataDecoder` for the specified `MediaType`.
    ///
    ///     contentConfig.use(decoder: JSONDecoder(), for: .json)
    ///
    /// - parameters:
    ///     - decoder: `Decoder` to use.
    ///     - mediaType: `Decoder` will be used to decode this `MediaType`.
    public mutating func use(decoder: HTTPMessageDecoder & DataDecoder, for mediaType: MediaType) {
        use(httpDecoder: decoder, for: mediaType)
        use(dataDecoder: decoder, for: mediaType)
    }

    /// Adds an `HTTPMessage` and `DataEncoder` by type for the specified `MediaType`.
    /// - note: The type will be resolved from the service-container at boot.
    ///
    ///     contentConfig.use(encoder: JSONEncoder.self, for: .json)
    ///
    /// - parameters:
    ///     - encoder: `Encoder` type to use.
    ///     - mediaType: `Encoder` will be used to encode this `MediaType`.
    public mutating func use<B>(encoder: B.Type, for mediaType: MediaType) where B: HTTPMessageEncoder & DataEncoder {
        use(httpEncoder: encoder, for: mediaType)
        use(dataEncoder: encoder, for: mediaType)
    }

    /// Adds an `HTTPMessage` and `DataDecoder` by type for the specified `MediaType`.
    /// - note: The type will be resolved from the service-container at boot.
    ///
    ///     contentConfig.use(decoder: JSONDecoder.self, for: .json)
    ///
    /// - parameters:
    ///     - decoder: `Decoder` type to use.
    ///     - mediaType: `Decoder` will be used to decode this `MediaType`.
    public mutating func use<B>(decoder: B.Type, for mediaType: MediaType) where B: HTTPMessageDecoder & DataDecoder {
        use(httpDecoder: decoder, for: mediaType)
        use(dataDecoder: decoder, for: mediaType)
    }

    // MARK: Message

    /// Adds an `HTTPMessageEncoder` for the specified `MediaType`.
    ///
    ///     contentConfig.use(httpEncoder: JSONEncoder(), for: .json)
    ///
    /// - parameters:
    ///     - httpEncoder: `HTTPMessageEncoder` to use.
    ///     - mediaType: `HTTPMessageEncoder` will be used to encode this `MediaType`.
    public mutating func use(httpEncoder: HTTPMessageEncoder, for mediaType: MediaType) {
        self.httpEncoders[mediaType] = { container in
            return httpEncoder
        }
    }

    /// Adds an `HTTPMessageDecoder` for the specified `MediaType`.
    ///
    ///     contentConfig.use(httpDecoder: JSONDecoder(), for: .json)
    ///
    /// - parameters:
    ///     - httpDecoder: `HTTPMessageDecoder` to use.
    ///     - mediaType: `HTTPMessageDecoder` will be used to decode this `MediaType`.
    public mutating func use(httpDecoder: HTTPMessageDecoder, for mediaType: MediaType) {
        self.httpDecoders[mediaType] = { container in
            return httpDecoder
        }
    }

    /// Adds an `HTTPMessageEncoder` by type for the specified `MediaType`.
    ///
    ///     contentConfig.use(httpEncoder: JSONEncoder.self, for: .json)
    ///
    /// - parameters:
    ///     - httpEncoder: `HTTPMessageEncoder` type to use.
    ///     - mediaType: `HTTPMessageEncoder` will be used to encode this `MediaType`.
    public mutating func use<B>(httpEncoder: B.Type, for mediaType: MediaType) where B: HTTPMessageEncoder {
        self.httpEncoders[mediaType] = { container in
            return try container.make(B.self)
        }
    }

    /// Adds an `HTTPMessageDecoder` by type for the specified `MediaType`.
    ///
    ///     contentConfig.use(httpDecoder: JSONDecoder.self, for: .json)
    ///
    /// - parameters:
    ///     - httpDecoder: `HTTPMessageDecoder` type to use.
    ///     - mediaType: `HTTPMessageDecoder` will be used to decode this `MediaType`.
    public mutating func use<B>(httpDecoder: B.Type, for mediaType: MediaType) where B: HTTPMessageDecoder {
        self.httpDecoders[mediaType] = { container in
            return try container.make(B.self)
        }
    }

    // MARK: Data

    /// Adds an `DataEncoder` for the specified `MediaType`.
    ///
    ///     contentConfig.use(dataEncoder: JSONEncoder(), for: .json)
    ///
    /// - parameters:
    ///     - dataEncoder: `DataEncoder` to use.
    ///     - mediaType: `DataEncoder` will be used to encode this `MediaType`.
    public mutating func use(dataEncoder: DataEncoder, for mediaType: MediaType) {
        self.dataEncoders[mediaType] = { container in
            return dataEncoder
        }
    }

    /// Adds an `DataDecoder` for the specified `MediaType`.
    ///
    ///     contentConfig.use(dataDecoder: JSONDecoder(), for: .json)
    ///
    /// - parameters:
    ///     - dataDecoder: `DataDecoder` to use.
    ///     - mediaType: `DataDecoder` will be used to decode this `MediaType`.
    public mutating func use(dataDecoder: DataDecoder, for mediaType: MediaType) {
        self.dataDecoders[mediaType] = { container in
            return dataDecoder
        }
    }

    /// Adds an `DataEncoder` by type for the specified `MediaType`.
    ///
    ///     contentConfig.use(dataEncoder: JSONEncoder.self, for: .json)
    ///
    /// - parameters:
    ///     - dataEncoder: `DataEncoder` type to use.
    ///     - mediaType: `DataEncoder` will be used to encode this `MediaType`.
    public mutating func use<D>(dataEncoder: D.Type, for mediaType: MediaType) where D: DataEncoder {
        self.dataEncoders[mediaType] = { container in
            return try container.make(D.self)
        }
    }

    /// Adds an `DataDecoder` by type for the specified `MediaType`.
    ///
    ///     contentConfig.use(dataDecoder: JSONDecoder.self, for: .json)
    ///
    /// - parameters:
    ///     - dataDecoder: `DataDecoder` type to use.
    ///     - mediaType: `DataDecoder` will be used to decode this `MediaType`.
    public mutating func use<D>(dataDecoder: D.Type, for mediaType: MediaType) where D: DataDecoder {
        self.dataDecoders[mediaType] = { container in
            return try container.make(D.self)
        }
    }

    // MARK: Resolve

    /// Creates a `ContentCoders` for this `ContentConfig` using the supplied `Container`.
    ///
    /// - parameters:
    ///     - container: `Container` to resolve coder types on.
    public func resolve(on container: Container) throws -> ContentCoders {
        return try ContentCoders(
            httpEncoders: httpEncoders.mapValues { try $0(container) },
            httpDecoders: httpDecoders.mapValues { try $0(container) },
            dataEncoders: dataEncoders.mapValues { try $0(container) },
            dataDecoders: dataDecoders.mapValues { try $0(container) }
        )
    }
}
