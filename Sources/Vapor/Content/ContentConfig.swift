import Foundation
import FormURLEncoded

/// Configures which encoders/decoders to use for a given media type.
public struct ContentConfig: Service {
    /// Configured encoders.
    var encoders: [MediaType: BodyEncoder]

    /// Configured decoders.
    var decoders: [MediaType: BodyDecoder]

    /// Create a new content config.
    public init() {
        self.encoders = [:]
        self.decoders = [:]
    }

    /// Adds an encoder for the specified media type.
    public mutating func use(encoder: BodyEncoder, for mediaType: MediaType) {
        self.encoders[mediaType] = encoder
    }

    /// Adds a decoder for the specified media type.
    public mutating func use(decoder: BodyDecoder, for mediaType: MediaType) {
        self.decoders[mediaType] = decoder
    }

    /// Returns an encoder for the specified media type or throws an error.
    func requireEncoder(for mediaType: MediaType) throws -> BodyEncoder {
        guard let encoder = encoders[mediaType] else {
            throw VaporError(identifier: "encoder-missing", reason: "There is no known encoder for \(mediaType)")
        }

        return encoder
    }

    /// Returns a decoder for the specified media type or throws an error.
    func requireDecoder(for mediaType: MediaType) throws -> BodyDecoder {
        guard let decoder = decoders[mediaType] else {
            throw VaporError(identifier: "encoder-missing", reason: "There is no known decoder for \(mediaType)")
        }

        return decoder
    }
}

/// MARK: Default

extension ContentConfig {
    public static func `default`() -> ContentConfig {
        var config = ContentConfig()

        // json
        config.use(encoder: JSONEncoder(), for: .json)
        config.use(decoder: JSONDecoder(), for: .json)

        // data
        config.use(encoder: DataEncoder(), for: .plainText)
        config.use(encoder: DataEncoder(), for: .html)


        // form-urlencoded
        config.use(encoder: FormURLEncoder(), for: .urlEncodedForm)
        config.use(decoder: FormURLDecoder(), for: .urlEncodedForm)

        return config
    }
}

extension FormURLEncoder: BodyEncoder {}
extension FormURLDecoder: BodyDecoder {}
