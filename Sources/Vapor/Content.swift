import Async
import HTTP
import Foundation
import Service

/// Representable as content in an HTTP message.
public protocol Content: Codable, ResponseCodable, RequestCodable, FutureType {
    /// The default media type to use when _encoding_ this
    /// content. This can be overridden at the encode call.
    static var defaultMediaType: MediaType { get }
}

extension Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .json
    }

    /// See RequestEncodable.encode
    public func encode(to req: inout Request) throws -> Future<Void> {
        try req.content.encode(self)
        return .done
    }

    /// See ResponseEncodable.encode
    public func encode(to res: inout Response, for req: Request) throws -> Future<Void> {
        try res.content.encode(self)
        return .done
    }

    /// See RequestDecodable.decode
    public static func decode(from req: Request) throws -> Future<Self> {
        let content = try req.content.decode(Self.self)
        return Future(content)
    }

    /// See ResponseDecodable.decode
    public static func decode(from res: Response, for req: Request) throws -> Future<Self> {
        let content = try res.content.decode(Self.self)
        return Future(content)
    }
}


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

extension ContentConfig {
    public static func `default`() -> ContentConfig {
        var config = ContentConfig()

        // json
        config.use(encoder: JSONEncoder(), for: .json)
        config.use(decoder: JSONDecoder(), for: .json)

        // html
        config.use(encoder: HTMLEncoder(), for: .html)
        
        return config
    }
}

/// Encodes encodable types to an HTTP body.
public protocol DataEncoder {
    /// Serializes an encodable type to the data in an HTTP body.
    func encode<T: Encodable>(_ encodable: T) throws -> Data
}

/// Decodes decodable types from an HTTP body.
public protocol DataDecoder {
    /// Parses a decodable type from the data in the HTTP body.
    func decode<T: Decodable>(_ decodable: T.Type, from data: Data) throws -> T
}

// MARK: Message

extension ContentContainer {
    /// Serializes the supplied content to this message.
    /// Uses the Content's default media type if none is supplied.
    public mutating func encode<C: Content>(_ content: C, as mediaType: MediaType = C.defaultMediaType) throws {
        let coders = try container.make(ContentConfig.self, for: ContentContainer.self)
        let encoder = try coders.requireEncoder(for: mediaType)
        message.body = try Body(encoder.encode(content))
        message.mediaType = mediaType
    }
}

extension ContentContainer {
    /// Parses the supplied content from the mesage.
    public func decode<C: Content>(_ content: C.Type) throws -> C {
        let coders = try container.make(ContentConfig.self, for: ContentContainer.self)
        guard let mediaType = message.mediaType else {
            throw "no media type"
        }
        guard let data = message.body.data else {
            throw "no body data"
        }
        let encoder = try coders.requireDecoder(for: mediaType)
        return try encoder.decode(C.self, from: data)
    }
}

extension QueryContainer {
    /// Parses the supplied content from the mesage.
    public func decode<C: Content>(_ content: C.Type) throws -> C {
        let coders = try container.make(ContentConfig.self, for: ContentContainer.self)
        let encoder = try coders.requireDecoder(for: .urlEncodedForm)
        return try encoder.decode(C.self, from: Data(query.utf8))
    }
}

// MARK: Foundation

extension JSONEncoder: DataEncoder {}
extension JSONDecoder: DataDecoder {}

extension String: Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .html
    }
}

extension Int: Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .html
    }
}

extension Array: Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .json
    }
}

extension Request {
    public func makeResponse() -> Response {
        return Response(on: self, using: self)
    }
}

extension Response {
    public func makeRequest() -> Request {
        return Request(on: self, using: self)
    }
}

