/// Stores configured `HTTPBodyDecoder` and `HTTPBodyEncoder`.
public struct ContentCoders: Service, ServiceType {
    /// See `ServiceType.serviceSupports`
    public static let serviceSupports: [Any.Type] = []

    /// See `ServiceType.makeService`
    public static func makeService(for worker: Container) throws -> ContentCoders {
        let config = try worker.make(ContentConfig.self)
        return try config.boot(using: worker)
    }

    /// Configured encoders.
    private let encoders: [MediaType: HTTPBodyEncoder]

    /// Configured decoders.
    private let decoders: [MediaType: HTTPBodyDecoder]

    /// Internal init for creating a `ContentCoders`.
    internal init(encoders: [MediaType: HTTPBodyEncoder], decoders: [MediaType: HTTPBodyDecoder]) {
        self.encoders = encoders
        self.decoders = decoders
    }

    /// Returns an encoder for the specified media type or throws an error.
    public func requireEncoder(for mediaType: MediaType) throws -> HTTPBodyEncoder {
        guard let encoder = encoders[mediaType] else {
            throw VaporError(identifier: "contentEncoder", reason: "There is no configured encoder for \(mediaType)", source: .capture())
        }

        return encoder
    }

    /// Returns a decoder for the specified media type or throws an error.
    public func requireDecoder(for mediaType: MediaType) throws -> HTTPBodyDecoder {
        guard let decoder = decoders[mediaType] else {
            throw VaporError(identifier: "contentDecoder", reason: "There is no configured decoder for \(mediaType)", source: .capture())
        }

        return decoder
    }
}
