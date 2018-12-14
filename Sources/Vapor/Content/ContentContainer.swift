public struct ContentContainer<Message>
    where Message: HTTPMessage
{
    public var message: Message
    
    public init(message: Message) {
        self.message = message
    }
    
    public mutating func encode<Content>(_ content: Content, using encoder: HTTPMessageEncoder) throws
        where Content: Encodable
    {
        try encoder.encode(content, to: &self.message, on: EmbeddedEventLoop())
    }
    
    public mutating func decode<Content>(_ content: Content.Type, using decoder: HTTPMessageDecoder) throws -> Content
        where Content: Decodable
    {
        return try decoder.decode(Content.self, from: self.message, maxSize: 65_000, on: EmbeddedEventLoop()).wait()
    }
}

#warning("TODO: re-impl ContentContainer")
///// Helper for encoding and decoding `Content` from an HTTP message.
/////
/////     req.content.decode(User.self)
/////
///// See `Request` and `Response` for more information.
//public struct ContentContainer<Message> where Message: HTTPMessage {
//    /// The wrapped message container.
//    internal var message: Message
//
//    /// Creates a new `ContentContainer`.
//    internal init(_ message: Message) {
//        self.message = message
//    }
//
//    // MARK: JSON
//
//    /// Serializes an `Encodable` object to this message using a custom `JSONEncoder`.
//    ///
//    ///     try res.content.encode(json: user, using: .custom(format: .prettyPrinted))
//    ///
//    /// See `JSONEncoder.custom(...)` for a convenient way to create a customized instance.
//    ///
//    /// - parameters:
//    ///     - json: Instance of generic `Encodable` to serialize to this HTTP message.
//    ///     - encoder: Specific `JSONEncoder` to use.
//    /// - throws: Errors during serialization.
//    public func encode<E>(json: E, using encoder: JSONEncoder) throws where E: Encodable {
//        try encode(json, using: encoder)
//    }
//
//    /// Parses a `Decodable` type from this HTTP message. This method supports streaming HTTP bodies (chunked) and can run asynchronously.
//    /// See `syncDecode(_:)` for the non-streaming, synchronous version.
//    ///
//    ///     let user = req.content.decode(json: User.self, using: .custom(dates: .iso8601))
//    ///     print(user) // Future<User>
//    ///
//    /// This method accepts a custom `JSONDecoder`. See `JSONDecoder.custom(...)` for a convenient way to create a customized instance.
//    ///
//    /// - parameters:
//    ///     - content: `Decodable` type to decode from this HTTP message.
//    ///     - maxSize: Maximum streaming body size to support (does not apply to static bodies).
//    ///     - decoder: Custom `JSONDecoder` to use.
//    /// - returns: Future instance of the `Decodable` type.
//    /// - throws: Any errors making the decoder for this media type or parsing the message.
//    public func decode<D>(json: D.Type, maxSize: Int = 65_536, using decoder: JSONDecoder) throws -> EventLoopFuture<D> where D: Decodable {
//        return try decode(D.self, maxSize: maxSize, using: decoder)
//    }
//
//    // MARK: Content
//
//    /// Serializes an `Encodable` object to this message using specific `HTTPMessageEncoder`.
//    ///
//    ///     try req.content.encode(user, using: JSONEncoder())
//    ///
//    /// - parameters:
//    ///     - encodable: Instance of generic `Encodable` to serialize to this HTTP message.
//    ///     - encoder: Specific `HTTPMessageEncoder` to use.
//    /// - throws: Errors during serialization.
//    public func encode<E>(_ encodable: E, using encoder: HTTPMessageEncoder) throws where E: Encodable {
//        try encoder.encode(encodable, to: &message)
//    }
//
//    /// Parses a `Decodable` type from this HTTP message. This method supports streaming HTTP bodies (chunked) and can run asynchronously.
//    /// See `syncDecode(_:)` for the non-streaming, synchronous version.
//    ///
//    ///     let user = req.content.decode(json: User.self, using: JSONDecoder())
//    ///     print(user) // Future<User>
//    ///
//    /// This method accepts a custom `HTTPMessageDecoder`.
//    ///
//    /// - parameters:
//    ///     - content: `Decodable` type to decode from this HTTP message.
//    ///     - maxSize: Maximum streaming body size to support (does not apply to static bodies).
//    ///     - decoder: Custom `HTTPMessageDecoder` to use.
//    /// - returns: Future instance of the `Decodable` type.
//    /// - throws: Any errors making the decoder for this media type or parsing the message.
//    public func decode<D>(_ content: D.Type, maxSize: Int = 65_536, using decoder: HTTPMessageDecoder) throws -> Future<D> where D: Decodable {
//        return try decoder.decode(D.self, from: container.http, maxSize: maxSize, on: container)
//    }
//
//    // MARK: Single Value
//
//    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
//    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
//    /// See `syncGet(_:at:)` for the streaming version.
//    ///
//    /// Note: This is a non-throwing subscript convenience method for `get(_:at:)`
//    ///
//    ///     let name: Future<String?> = try req.content["user", "name"]
//    ///
//    /// - parameters:
//    ///     - keyPath: One or more key path components to the desired value.
//    /// - returns: Optional decoded `Decodable` value.
//    public subscript<D>(_ keyPath: BasicKeyRepresentable...) -> Future<D?>
//        where D: Decodable
//    {
//        return self[D.self, at: keyPath]
//    }
//
//    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
//    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
//    /// See `syncGet(_:at:)` for the streaming version.
//    ///
//    /// Note: This is a non-throwing subscript convenience method for `get(_:at:)`
//    ///
//    ///     let name = try req.content[String.self, at: "user", "name"]
//    ///     print(name) // Future<String?>
//    ///
//    /// - parameters:
//    ///     - type: The `Decodable` value type to decode.
//    ///     - keyPath: One or more key path components to the desired value.
//    /// - returns: Optional decoded `Decodable` value.
//    public subscript<D>(_ type: D.Type, at keyPath: BasicKeyRepresentable...) -> Future<D?>
//        where D: Decodable
//    {
//        return self[D.self, at: keyPath]
//    }
//
//    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
//    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
//    /// See `syncGet(_:at:)` for the streaming version.
//    ///
//    /// Note: This is a non-throwing subscript convenience method for `get(_:at:)`. This is the non-variadic version.
//    ///
//    ///     let name = try req.content[String.self, at: "user", "name"]
//    ///     print(name) // Future<String?>
//    ///
//    /// - parameters:
//    ///     - type: The `Decodable` value type to decode.
//    ///     - keyPath: One or more key path components to the desired value.
//    /// - returns: Optional decoded `Decodable` value.
//    public subscript<D>(_ type: D.Type, at keyPath: [BasicKeyRepresentable]) -> Future<D?>
//        where D: Decodable
//    {
//        let promise = container.eventLoop.newPromise(D?.self)
//        get(at: keyPath).do { value in
//            promise.succeed(result: value)
//        }.catch { err in
//            promise.succeed(result: nil)
//        }
//        return promise.futureResult
//    }
//
//    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
//    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
//    /// See `syncGet(_:at:)` for the streaming version.
//    ///
//    ///     let name = try req.content.get(String.self, at: "user", "name")
//    ///     print(name) // Future<String>
//    ///
//    /// - parameters:
//    ///     - type: The `Decodable` value type to decode.
//    ///     - keyPath: One or more key path components to the desired value.
//    ///     - maxSize: Maximum streaming body size to support (does not apply to non-streaming bodies).
//    /// - returns: Future decoded `Decodable` value.
//    public func get<D>(_ type: D.Type = D.self, at keyPath: BasicKeyRepresentable...) -> Future<D>
//        where D: Decodable
//    {
//        return get(at: keyPath)
//    }
//
//    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
//    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
//    /// See `syncGet(_:at:)` for the streaming version.
//    ///
//    /// Note: This is the non-variadic version.
//    ///
//    ///     let name = try req.content.get(String.self, at: "user", "name")
//    ///     print(name) // Future<String>
//    ///
//    /// - parameters:
//    ///     - type: The `Decodable` value type to decode.
//    ///     - keyPath: One or more key path components to the desired value.
//    ///     - maxSize: Maximum streaming body size to support (does not apply to non-streaming bodies).
//    /// - returns: Future decoded `Decodable` value.
//    public func get<D>(_ type: D.Type = D.self, at keyPath: [BasicKeyRepresentable], maxSize: Int = 65_536) -> Future<D>
//        where D: Decodable
//    {
//        return Future.flatMap(on: container) {
//            return try self.requireHTTPDecoder().get(at: keyPath.makeBasicKeys(), from: self.container.http, maxSize: maxSize, on: self.container)
//        }
//    }
//
//    // MARK: Sync
//
//    /// Parses a `Decodable` type from this HTTP message. This method does _not_ support streaming HTTP bodies (chunked) and runs synchronously.
//    /// See `decode(_:maxSize:)` for the streaming version.
//    ///
//    ///     let user = try req.content.syncDecode(User.self)
//    ///     print(user) // User
//    ///
//    /// The HTTP message's `MediaType` will be used to lookup the relevant `HTTPBodyDecoder` to use.
//    ///
//    /// - parameters:
//    ///     - content: `Decodable` type to decode from this HTTP message.
//    /// - returns: Instance of the `Decodable` type.
//    /// - throws: Any errors making the decoder for this media type or parsing the message.
//    ///           An error will also be thrown if this HTTP message's body type is streaming.
//    public func syncDecode<D>(_ content: D.Type) throws -> D where D: Decodable {
//        guard let data = container.http.body.data else {
//            throw VaporError(
//                identifier: "syncDecode",
//                reason: "Cannot use sync decode on a streaming body.",
//                suggestedFixes: [
//                    "Use `decode` instead of `syncDecode`."
//                ]
//            )
//        }
//        return try requireDataDecoder().decode(D.self, from: data)
//    }
//
//    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
//    /// This method does _not_ support streaming HTTP bodies (chunked) and runs synchronously.
//    /// See `get(_:at:)` for the streaming version.
//    ///
//    ///     let name = try req.content.syncGet(String.self, at: "user", "name")
//    ///     print(name) // String
//    ///
//    /// - parameters:
//    ///     - type: The `Decodable` value type to decode.
//    ///     - keyPath: One or more key path components to the desired value.
//    /// - throws: Any errors making the correct decoder, parsing the value, or if the HTTP body is streaming.
//    /// - returns: Decoded `Decodable` value.
//    public func syncGet<D>(_ type: D.Type = D.self, at keyPath: BasicKeyRepresentable...) throws -> D
//        where D: Decodable
//    {
//        return try syncGet(at: keyPath)
//    }
//
//    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
//    /// This method does _not_ support streaming HTTP bodies (chunked) and runs synchronously.
//    /// See `get(_:at:)` for the streaming version.
//    ///
//    /// Note: This is the non-variadic version.
//    ///
//    ///     let name = try req.content.syncGet(String.self, at: "user", "name")
//    ///     print(name) // String
//    ///
//    /// - parameters:
//    ///     - type: The `Decodable` value type to decode.
//    ///     - keyPath: One or more key path components to the desired value.
//    /// - throws: Any errors making the correct decoder, parsing the value, or if the HTTP body is streaming.
//    /// - returns: Decoded `Decodable` value.
//    public func syncGet<D>(_ type: D.Type = D.self, at keyPath: [BasicKeyRepresentable]) throws -> D
//        where D: Decodable
//    {
//        guard let data = container.http.body.data else {
//            throw VaporError(
//                identifier: "syncGet",
//                reason: "Cannot use sync decode on a streaming body.",
//                suggestedFixes: ["Use `get` instead of `syncGet`."]
//            )
//        }
//        return try requireDataDecoder().get(at: keyPath.makeBasicKeys(), from: data)
//    }
//}
