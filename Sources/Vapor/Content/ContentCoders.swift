/// Stores configured `HTTPBodyDecoder` and `HTTPBodyEncoder`.
public struct ContentCoders: Service, ServiceType {
    /// See `ServiceType.serviceSupports`
    public static let serviceSupports: [Any.Type] = []

    /// See `ServiceType.makeService`
    public static func makeService(for worker: Container) throws -> ContentCoders {
        let config = try worker.make(ContentConfig.self)
        return try config.boot(using: worker)
    }

    /// Configured `HTTPBodyEncoder`s.
    private let bodyEncoders: [MediaType: HTTPBodyEncoder]

    /// Configured `HTTPBodyDecoder`s.
    private var bodyDecoders: [MediaType: HTTPBodyDecoder]

    /// Configured `DataEncoder`s.
    private var dataEncoders: [MediaType: DataEncoder]

    /// Configured `DataDecoder`s.
    private var dataDecoders: [MediaType: DataDecoder]

    /// Internal init for creating a `ContentCoders`.
    internal init(
        bodyEncoders: [MediaType: HTTPBodyEncoder],
        bodyDecoders: [MediaType: HTTPBodyDecoder],
        dataEncoders: [MediaType: DataEncoder],
        dataDecoders: [MediaType: DataDecoder]
    ) {
        self.bodyEncoders = bodyEncoders
        self.bodyDecoders = bodyDecoders
        self.dataEncoders = dataEncoders
        self.dataDecoders = dataDecoders
    }

    /// Returns a `HTTPBodyEncoder` for the specified `MediaType` or throws an error.
    public func requireBodyEncoder(for mediaType: MediaType) throws -> HTTPBodyEncoder {
        guard let encoder = bodyEncoders[mediaType] else {
            throw VaporError(identifier: "httpBodyEncoder", reason: "There is no configured HTTP body encoder for \(mediaType)", source: .capture())
        }

        return encoder
    }

    /// Returns a `HTTPBodyDecoder` for the specified `MediaType` or throws an error.
    public func requireBodyDecoder(for mediaType: MediaType) throws -> HTTPBodyDecoder {
        guard let decoder = bodyDecoders[mediaType] else {
            throw VaporError(identifier: "httpBodyDecoder", reason: "There is no configured HTTP body decoder for \(mediaType)", source: .capture())
        }

        return decoder
    }

    /// Returns a `DataEncoder` for the specified `MediaType` or throws an error.
    public func requireDataEncoder(for mediaType: MediaType) throws -> DataEncoder {
        guard let encoder = dataEncoders[mediaType] else {
            throw VaporError(identifier: "dataEncoder", reason: "There is no configured data encoder for \(mediaType)", source: .capture())
        }

        return encoder
    }

    /// Returns a `DataDecoder` for the specified `MediaType` or throws an error.
    public func requireDataDecoder(for mediaType: MediaType) throws -> DataDecoder {
        guard let decoder = dataDecoders[mediaType] else {
            throw VaporError(identifier: "dataDecoder", reason: "There is no configured data decoder for \(mediaType)", source: .capture())
        }

        return decoder
    }
}
