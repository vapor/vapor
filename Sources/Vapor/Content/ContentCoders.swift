/// Stores configured `HTTPBodyDecoder` and `HTTPBodyEncoder`.
public struct ContentCoders: Service, ServiceType {
    /// See `ServiceType.serviceSupports`
    public static let serviceSupports: [Any.Type] = []

    /// See `ServiceType.makeService`
    public static func makeService(for worker: Container) throws -> ContentCoders {
        let config = try worker.make(ContentConfig.self)
        return try config.boot(using: worker)
    }

    /// Configured `HTTPMessageEncoder`s.
    private let httpEncoders: [MediaType: HTTPMessageEncoder]

    /// Configured `HTTPMessageDecoder`s.
    private var httpDecoders: [MediaType: HTTPMessageDecoder]

    /// Configured `DataEncoder`s.
    private var dataEncoders: [MediaType: DataEncoder]

    /// Configured `DataDecoder`s.
    private var dataDecoders: [MediaType: DataDecoder]

    /// Internal init for creating a `ContentCoders`.
    internal init(
        httpEncoders: [MediaType: HTTPMessageEncoder],
        httpDecoders: [MediaType: HTTPMessageDecoder],
        dataEncoders: [MediaType: DataEncoder],
        dataDecoders: [MediaType: DataDecoder]
    ) {
        self.httpEncoders = httpEncoders
        self.httpDecoders = httpDecoders
        self.dataEncoders = dataEncoders
        self.dataDecoders = dataDecoders
    }

    /// Returns a `HTTPMessageEncoder` for the specified `MediaType` or throws an error.
    public func requireHTTPEncoder(for mediaType: MediaType) throws -> HTTPMessageEncoder {
        guard let encoder = httpEncoders[mediaType] else {
            throw VaporError(identifier: "httpEncoder", reason: "There is no configured HTTP encoder for \(mediaType)", source: .capture())
        }

        return encoder
    }

    /// Returns a `HTTPMessageDecoder` for the specified `MediaType` or throws an error.
    public func requireHTTPDecoder(for mediaType: MediaType) throws -> HTTPMessageDecoder {
        guard let decoder = httpDecoders[mediaType] else {
            throw VaporError(identifier: "httpDecoder", reason: "There is no configured HTTP decoder for \(mediaType)", source: .capture())
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
