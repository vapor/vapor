import Foundation
import FormURLEncoded

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

    /// Configured encoders.
    private var lazyEncoders: [MediaType: Lazy<HTTPBodyEncoder>]

    /// Configured decoders.
    private var lazyDecoders: [MediaType: Lazy<HTTPBodyDecoder>]

    /// Create a new content config.
    public init() {
        self.lazyEncoders = [:]
        self.lazyDecoders = [:]
    }

    /// Adds an encoder for the specified media type.
    public mutating func use(encoder: HTTPBodyEncoder, for mediaType: MediaType) {
        self.lazyEncoders[mediaType] = { container in
            return encoder
        }
    }

    /// Adds a decoder for the specified media type.
    public mutating func use(decoder: HTTPBodyDecoder, for mediaType: MediaType) {
        self.lazyDecoders[mediaType] = { container in
            return decoder
        }
    }

    /// Adds an encoder for the specified media type.
    public mutating func use<B>(encoder: B.Type, for mediaType: MediaType) where B: HTTPBodyEncoder {
        self.lazyEncoders[mediaType] = { container in
            return try container.make(B.self)
        }
    }

    /// Adds a decoder for the specified media type.
    public mutating func use<B>(decoder: B.Type, for mediaType: MediaType) where B: HTTPBodyDecoder {
        self.lazyDecoders[mediaType] = { container in
            return try container.make(B.self)
        }
    }

    /// Creates all lazy coders.
    internal func boot(using container: Container) throws -> ContentCoders {
        return try ContentCoders(
            encoders: lazyEncoders.mapValues { try $0(container) },
            decoders: lazyDecoders.mapValues { try $0(container) }
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
        config.use(encoder: PlaintextEncoder(), for: .html)

        // form-urlencoded
        config.use(encoder: FormURLEncoder(), for: .urlEncodedForm)
        config.use(decoder: FormURLDecoder(), for: .urlEncodedForm)

        return config
    }
}
