import Foundation

/// Helper for encoding/decoding HTTP content.
public struct ContentContainer {
    var container: SubContainer
    var body: HTTPBody
    let mediaType: MediaType?
    var update: (HTTPBody, MediaType) -> ()
}

extension ContentContainer {
    /// Serializes the supplied content to this message.
    /// Uses the Content's default media type if none is supplied.
    public func encode<C>(_ content: C) throws where C: Content {
        let encoder = try requireEncoder(for: C.defaultMediaType)
        let body = try encoder.encodeBody(from: content)
        update(body, C.defaultMediaType)
    }

    /// Serializes the supplied content to this message.
    /// Uses the Content's default media type if none is supplied.
    public func encode<E>(_ encodable: E, as mediaType: MediaType) throws where E: Encodable {
        let encoder = try requireEncoder(for: mediaType)
        let body = try encoder.encodeBody(from: encodable)
        update(body, mediaType)
    }
    
    /// Parses the supplied content from the mesage.
    public func decode<D>(_ content: D.Type) throws -> D where D: Decodable {
        let decoder = try requireDecoder()
        return try decoder.decode(D.self, from: body)
    }

    /// Creates a data encoder from the content config or throws.
    private func requireEncoder(for mediaType: MediaType) throws -> BodyEncoder {
        let coders = try container.superContainer.make(ContentConfig.self, for: ContentContainer.self)
        return try coders.requireEncoder(for: mediaType)
    }

    /// Creates a data decoder from the content config or throws.
    private func requireDecoder() throws -> BodyDecoder {
        let coders = try container.superContainer.make(ContentConfig.self, for: ContentContainer.self)
        guard let mediaType = mediaType else {
            throw VaporError(identifier: "no-media-type", reason: "Cannot decode content without mediatype")
        }
        return try coders.requireDecoder(for: mediaType)
    }
}

// MARK: Single value

extension ContentContainer {
    /// Convenience for accessing a single value from the content
    public subscript<D>(_ keyPath: BasicKeyRepresentable...) -> D?
        where D: Decodable
    {
        return self[D.self, at: keyPath]
    }

    /// Convenience for accessing a single value from the content
    public subscript<D>(_ type: D.Type, at keyPath: BasicKeyRepresentable...) -> D?
        where D: Decodable
    {
        return self[D.self, at: keyPath]
    }

    /// Convenience for accessing a single value from the content
    public subscript<D>(_ type: D.Type, at keyPath: [BasicKeyRepresentable]) -> D?
        where D: Decodable
    {
        return try? get(at: keyPath)
    }

    /// Convenience for accessing a single value from the content
    public func get<D>(_ type: D.Type = D.self, at keyPath: [BasicKeyRepresentable]) throws -> D
        where D: Decodable
    {
        let decoder = try requireDecoder()
        return try decoder.get(at: keyPath.makeBasicKeys(), from: body)
    }
}
