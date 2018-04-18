/// Helper for encoding and decoding `Content` from an HTTP message.
///
/// See `Response.content` and `Request.content` for more information.
public struct ContentContainer<M> where M: HTTPMessageContainer {
    /// The wrapped message container.
    var container: M

    /// Creates a new `ContentContainer`.
    init(_ container: M) {
        self.container = container
    }

    // MARK: Encode & Decode

    /// Serializes `Content` to this HTTP message. Uses the Content's default media type if none is supplied.
    ///
    ///     try req.content.encode(user)
    ///
    /// - parameters:
    ///     - content: Instance of generic `Content` to serialize to this HTTP message.
    /// - throws: Errors making encoder for the `Content` or errors during serialization.
    public func encode<C>(_ content: C, as mediaType: MediaType = C.defaultMediaType) throws where C: Content {
        try requireHTTPEncoder(for: mediaType).encode(content, to: &container.http, on: container)
    }

    /// Serializes an `Encodable` object to this message using specific `MediaType`.
    ///
    ///     try req.content.encode(user, as: .json)
    ///
    /// - parameters:
    ///     - encodable: Instance of generic `Encodable` to serialize to this HTTP message.
    ///     - mediaType: Specific `MediaType` to encode. This will be used to lookup an appropriate encoder from `ContentConfig`.
    /// - throws: Errors making encoder for the `Content` or errors during serialization.
    public func encode<E>(_ encodable: E, as mediaType: MediaType) throws where E: Encodable {
        try requireHTTPEncoder(for: mediaType).encode(encodable, to: &container.http, on: container)
    }
    
    /// Parses a `Decodable` type from this HTTP message. This method supports streaming HTTP bodies (chunked) and can run asynchronously
    /// See `syncDecode(_:)` for the non-streaming, synchronous version.
    ///
    ///     let user = try req.content.decode(User.self)
    ///     print(user) /// Future<User>
    ///
    /// The HTTP message's `MediaType` will be used to lookup the relevant `HTTPBodyDecoder` to use.
    ///
    /// - parameters:
    ///     - content: `Decodable` type to decode from this HTTP message.
    ///     - maxSize: Maximum streaming body size to support (does not apply to static bodies).
    /// - returns: Future instance of the `Decodable` type.
    /// - throws: Any errors making the decoder for this media type or parsing the message.
    public func decode<D>(_ content: D.Type, maxSize: Int = 65_536) throws -> Future<D> where D: Decodable {
        return try requireHTTPDecoder().decode(D.self, from: container.http, maxSize: maxSize, on: container)
    }

    // MARK: Single Value

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
    /// See `syncGet(_:at:)` for the streaming version.
    ///
    /// Note: This is a non-throwing subscript convenience method for `get(_:at:)`
    ///
    ///     let name: Future<String?> = try req.content["user", "name"]
    ///
    /// - parameters:
    ///     - keyPath: One or more key path components to the desired value.
    /// - returns: Optional decoded `Decodable` value.
    public subscript<D>(_ keyPath: BasicKeyRepresentable...) -> Future<D?>
        where D: Decodable
    {
        return self[D.self, at: keyPath]
    }

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
    /// See `syncGet(_:at:)` for the streaming version.
    ///
    /// Note: This is a non-throwing subscript convenience method for `get(_:at:)`
    ///
    ///     let name = try req.content[String.self, at: "user", "name"]
    ///     print(name) /// Future<String?>
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    /// - returns: Optional decoded `Decodable` value.
    public subscript<D>(_ type: D.Type, at keyPath: BasicKeyRepresentable...) -> Future<D?>
        where D: Decodable
    {
        return self[D.self, at: keyPath]
    }

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
    /// See `syncGet(_:at:)` for the streaming version.
    ///
    /// Note: This is a non-throwing subscript convenience method for `get(_:at:)`. This is the non-variadic version.
    ///
    ///     let name = try req.content[String.self, at: "user", "name"]
    ///     print(name) /// Future<String?>
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    /// - returns: Optional decoded `Decodable` value.
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

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
    /// See `syncGet(_:at:)` for the streaming version.
    ///
    ///     let name = try req.content.get(String.self, at: "user", "name")
    ///     print(name) /// Future<String>
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    ///     - maxSize: Maximum streaming body size to support (does not apply to non-streaming bodies).
    /// - returns: Future decoded `Decodable` value.
    public func get<D>(_ type: D.Type = D.self, at keyPath: BasicKeyRepresentable...) -> Future<D>
        where D: Decodable
    {
        return get(at: keyPath)
    }

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
    /// See `syncGet(_:at:)` for the streaming version.
    ///
    /// Note: This is the non-variadic version.
    ///
    ///     let name = try req.content.get(String.self, at: "user", "name")
    ///     print(name) /// Future<String>
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    ///     - maxSize: Maximum streaming body size to support (does not apply to non-streaming bodies).
    /// - returns: Future decoded `Decodable` value.
    public func get<D>(_ type: D.Type = D.self, at keyPath: [BasicKeyRepresentable], maxSize: Int = 65_536) -> Future<D>
        where D: Decodable
    {
        return Future.flatMap(on: container) {
            return try self.requireHTTPDecoder().get(at: keyPath.makeBasicKeys(), from: self.container.http, maxSize: maxSize, on: self.container)
        }
    }

    // MARK: Sync

    /// Parses a `Decodable` type from this HTTP message. This method does _not_ support streaming HTTP bodies (chunked) and runs synchronously.
    /// See `decode(_:maxSize:)` for the streaming version.
    ///
    ///     let user = try req.content.syncDecode(User.self)
    ///     print(user) /// User
    ///
    /// The HTTP message's `MediaType` will be used to lookup the relevant `HTTPBodyDecoder` to use.
    ///
    /// - parameters:
    ///     - content: `Decodable` type to decode from this HTTP message.
    /// - returns: Instace of the `Decodable` type.
    /// - throws: Any errors making the decoder for this media type or parsing the message.
    ///           An error will also be thrown if this HTTP message's body type is streaming.
    public func syncDecode<D>(_ content: D.Type) throws -> D where D: Decodable {
        guard let data = container.http.body.data else {
            throw VaporError(identifier: "streamingUnsupported", reason: "Cannot decode \(D.self) from streaming body.", source: .capture())
        }
        return try requireDataDecoder().decode(D.self, from: data)
    }

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method does _not_ support streaming HTTP bodies (chunked) and runs synchronously.
    /// See `get(_:at:)` for the streaming version.
    ///
    ///     let name = try req.content.syncGet(String.self, at: "user", "name")
    ///     print(name) /// String
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    /// - throws: Any errors making the correct decoder, parsing the value, or if the HTTP body is streaming.
    /// - returns: Decoded `Decodable` value.
    public func syncGet<D>(_ type: D.Type = D.self, at keyPath: BasicKeyRepresentable...) throws -> D
        where D: Decodable
    {
        return try syncGet(at: keyPath)
    }

    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method does _not_ support streaming HTTP bodies (chunked) and runs synchronously.
    /// See `get(_:at:)` for the streaming version.
    ///
    /// Note: This is the non-variadic version.
    ///
    ///     let name = try req.content.syncGet(String.self, at: "user", "name")
    ///     print(name) /// String
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    /// - throws: Any errors making the correct decoder, parsing the value, or if the HTTP body is streaming.
    /// - returns: Decoded `Decodable` value.
    public func syncGet<D>(_ type: D.Type = D.self, at keyPath: [BasicKeyRepresentable]) throws -> D
        where D: Decodable
    {
        guard let data = container.http.body.data else {
            throw VaporError(identifier: "streamingUnsupported", reason: "Cannot decode \(D.self) from streaming body.", source: .capture())
        }
        return try requireDataDecoder().get(at: keyPath.makeBasicKeys(), from: data)
    }

    // MARK: Private

    /// Looks up a `HTTPMessageEncoder` for the supplied `MediaType`.
    private func requireHTTPEncoder(for mediaType: MediaType) throws -> HTTPMessageEncoder {
        let coders = try container.make(ContentCoders.self)
        return try coders.requireHTTPEncoder(for: mediaType)
    }

    /// Looks up a `HTTPMessageDecoder` for the supplied `MediaType`.
    private func requireHTTPDecoder() throws -> HTTPMessageDecoder {
        let coders = try container.make(ContentCoders.self)
        guard let contentType = container.http.contentType else {
            throw VaporError(identifier: "contentType", reason: "Cannot decode content without content-type", source: .capture())
        }
        return try coders.requireHTTPDecoder(for: contentType)
    }

    /// Looks up a `DataDecoder` for the supplied `MediaType`.
    private func requireDataDecoder() throws -> DataDecoder {
        let coders = try container.make(ContentCoders.self)
        guard let contentType = container.http.contentType else {
            throw VaporError(identifier: "mediaType", reason: "Cannot decode content without content-type", source: .capture())
        }
        return try coders.requireDataDecoder(for: contentType)
    }
}

