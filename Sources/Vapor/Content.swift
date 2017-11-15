import HTTP
import Foundation
import Service

/// Representable as content in an HTTP message.
public protocol Content: Codable {
    /// The default media type to use when _encoding_ this
    /// content. This can be overridden at the encode call.
    static var defaultMediaType: MediaType { get }
}

/// Configures which encoders/decoders to use for a given media type.
public struct ContentConfig {
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
            throw "no encoder for \(mediaType)"
        }
        
        return encoder
    }

    /// Returns a decoder for the specified media type or throws an error.
    func requireDecoder(for mediaType: MediaType) throws -> BodyDecoder {
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
public protocol BodyEncoder {
    /// Serializes an encodable type to the data in an HTTP body.
    func encode<T: Encodable>(_ encodable: T) throws -> Body
}

/// Decodes decodable types from an HTTP body.
public protocol BodyDecoder {
    /// Parses a decodable type from the data in the HTTP body.
    func decode<T: Decodable>(_ decodable: T.Type, from body: Body) throws -> T
}

// MARK: Message

extension Message {
    /// Serializes the supplied content to this message.
    /// Uses the Content's default media type if none is supplied.
    public func content<C: Content>(_ content: C, as mediaType: MediaType = C.defaultMediaType) throws {
        guard let container = self.container else {
            throw "container required"
        }
        let coders = try container.make(ContentConfig.self, for: Self.self)
        let encoder = try coders.requireEncoder(for: mediaType)
        body = try encoder.encode(content)
        self.mediaType = mediaType
    }
}

extension Message {
    /// Parses the supplied content from the mesage.
    public func content<C: Content>(_ content: C.Type) throws -> C {
        guard let container = self.container else {
            throw "container required"
        }
        let coders = try container.make(ContentConfig.self, for: Self.self)
        guard let mediaType = self.mediaType else {
            throw "no media type"
        }
        let encoder = try coders.requireDecoder(for: mediaType)
        return try encoder.decode(content, from: body)
    }
}

// MARK: Foundation

extension JSONEncoder: BodyEncoder {
    /// See BodyEncoder.encode
    public func encode<T>(_ encodable: T) throws -> Body
        where T: Encodable
    {
        let data: Data = try encode(encodable)
        return Body(data)
    }
}

extension JSONDecoder: BodyDecoder {
    /// See BodyDecoder.decode
    public func decode<T>(_ decodable: T.Type, from body: Body) throws -> T
        where T: Decodable
    {
        return try decode(T.self, from: body.data)
    }
}

extension String: Content {
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .html
    }
}

extension String: ResponseRepresentable {
    /// See ResponseRepresentable.makeResponse
    public func makeResponse(for req: Request) throws -> Response {
        let res = Response(status: .ok)
        res.app = req.app
        try res.content(self)
        return res
    }
}

