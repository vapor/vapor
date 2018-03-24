import Foundation

/// Helper for encoding/decoding HTTP content.
public struct ContentContainer {
    internal var container: SubContainer
    internal var body: HTTPBody?
    internal let mediaType: MediaType?
    internal var update: (HTTPBody, MediaType) -> ()
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
    public func decode<D>(_ content: D.Type, maxSize: Int = 65_536) throws -> Future<D> where D: Decodable {
        let decoder = try requireDecoder()
        guard let body = self.body else {
            throw VaporError(identifier: "noBody", reason: "Cannot decode content from an HTTP message with body", source: .capture())
        }
        return try decoder.decode(D.self, from: body, maxSize: maxSize, on: container)
    }

    /// Creates a data encoder from the content config or throws.
    private func requireEncoder(for mediaType: MediaType) throws -> HTTPBodyEncoder {
        let coders = try container.superContainer.make(ContentCoders.self)
        return try coders.requireEncoder(for: mediaType)
    }

    /// Creates a data decoder from the content config or throws.
    private func requireDecoder() throws -> HTTPBodyDecoder {
        let coders = try container.superContainer.make(ContentCoders.self)
        guard let mediaType = mediaType else {
            throw VaporError(identifier: "mediaType", reason: "Cannot decode content without Media Type", source: .capture())
        }
        return try coders.requireDecoder(for: mediaType)
    }
}

// MARK: Single value

extension ContentContainer {
    /// Convenience for accessing a single value from the content
    public subscript<D>(_ keyPath: BasicKeyRepresentable...) -> Future<D?>
        where D: Decodable
    {
        return self[D.self, at: keyPath]
    }

    /// Convenience for accessing a single value from the content
    public subscript<D>(_ type: D.Type, at keyPath: BasicKeyRepresentable...) -> Future<D?>
        where D: Decodable
    {
        return self[D.self, at: keyPath]
    }

    /// Convenience for accessing a single value from the content
    public subscript<D>(_ type: D.Type, at keyPath: [BasicKeyRepresentable]) -> Future<D?>
        where D: Decodable
    {
        let promise = container.eventLoop.newPromise(D?.self)
        get(at: keyPath).do { value in
            promise.succeed(result: value)
        }.catch { err in
            promise.succeed(result: nil)
        }
        return promise.futureResult
    }

    /// Convenience for accessing a single value from the content
    public func get<D>(_ type: D.Type = D.self, at keyPath: BasicKeyRepresentable...) -> Future<D>
        where D: Decodable
    {
        return get(at: keyPath)
    }

    /// Convenience for accessing a single value from the content
    public func get<D>(_ type: D.Type = D.self, at keyPath: [BasicKeyRepresentable], maxSize: Int = 65_536) -> Future<D>
        where D: Decodable
    {
        do {
            let decoder = try requireDecoder()
            guard let body = self.body else {
                throw VaporError(identifier: "noBody", reason: "Cannot decode content from an HTTP message with body", source: .capture())
            }
            return try decoder.get(at: keyPath.makeBasicKeys(), from: body, maxSize: maxSize, on: container)
        } catch {
            return Future.map(on: container) { throw error }
        }
    }
}
