import Foundation

public struct ContentContainer {
    var container: SubContainer
    var body: HTTPBody
    let mediaType: MediaType?
    var update: (HTTPBody, MediaType) -> ()
}

extension ContentContainer {
    /// Serializes the supplied content to this message.
    /// Uses the Content's default media type if none is supplied.
    public func encode<C: Content>(_ content: C) throws {
        let coders = try container.superContainer.make(ContentConfig.self, for: ContentContainer.self)
        let encoder = try coders.requireEncoder(for: C.defaultMediaType)
        let body = try encoder.encodeBody(from: content)
        update(body, C.defaultMediaType)
    }

    /// Serializes the supplied content to this message.
    /// Uses the Content's default media type if none is supplied.
    public func encode<E: Encodable>(_ encodable: E, as mediaType: MediaType) throws {
        let coders = try container.superContainer.make(ContentConfig.self, for: ContentContainer.self)
        let encoder = try coders.requireEncoder(for: mediaType)
        let body = try encoder.encodeBody(from: encodable)
        update(body, mediaType)
    }
    
    /// Parses the supplied content from the mesage.
    public func decode<D: Decodable>(_ content: D.Type) throws -> D {
        let coders = try container.superContainer.make(ContentConfig.self, for: ContentContainer.self)
        guard let mediaType = mediaType else {
            throw "no media type"
        }
        
        let encoder = try coders.requireDecoder(for: mediaType)
        return try encoder.decode(D.self, from: body)
    }
}

extension QueryContainer {
    /// Parses the supplied content from the mesage.
    public func decode<D: Decodable>(_ decodable: D.Type) throws -> D {
        let coders = try container.superContainer.make(ContentConfig.self, for: QueryContainer.self)
        let encoder = try coders.requireDecoder(for: .urlEncodedForm)
        return try encoder.decode(D.self, from: HTTPBody(string: query))
    }
}
