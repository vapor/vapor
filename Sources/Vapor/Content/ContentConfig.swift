import Foundation
import FormURLEncoded

/// Configures which encoders/decoders to use for a given media type.
public struct ContentConfig {
    /// Configured encoders.
    var encoders: [MediaType: DataEncoder]

    /// Configured decoders.
    var decoders: [MediaType: DataDecoder]

    /// Create a new content config.
    public init() {
        self.encoders = [:]
        self.decoders = [:]
    }

    /// Adds an encoder for the specified media type.
    public mutating func use(encoder: DataEncoder, for mediaType: MediaType) {
        self.encoders[mediaType] = encoder
    }

    /// Adds a decoder for the specified media type.
    public mutating func use(decoder: DataDecoder, for mediaType: MediaType) {
        self.decoders[mediaType] = decoder
    }

    /// Returns an encoder for the specified media type or throws an error.
    func requireEncoder(for mediaType: MediaType) throws -> DataEncoder {
        guard let encoder = encoders[mediaType] else {
            throw "no encoder for \(mediaType)"
        }

        return encoder
    }

    /// Returns a decoder for the specified media type or throws an error.
    func requireDecoder(for mediaType: MediaType) throws -> DataDecoder {
        guard let decoder = decoders[mediaType] else {
            throw "no decoder for \(mediaType)"
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

        // html
        config.use(encoder: HTMLEncoder(), for: .html)


        // form-urlencoded
        config.use(encoder: FormURLEncoder(), for: .urlEncodedForm)
        config.use(decoder: FormURLDecoder(), for: .urlEncodedForm)

        return config
    }
}

extension FormURLEncoder: DataEncoder {}
extension FormURLDecoder: DataDecoder {}
